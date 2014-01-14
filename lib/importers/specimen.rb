require './lib/importers/importer_base.rb'
require 'resque'
module Importer
  require 'rbc'

  class LazyImport
    require 'rbc'

    def self.perform(go, bsi, batch, batch_id, options)
      go.call(bsi, batch, batch_id, options)
    end
  end

  class Pipe < ImporterBase

    def initialize(key, options={})
      @options = options
      debug = options[:debug]
      @bsi = RBC.new(key, options)
      @batch
      @batch_id
    end

    def import(all_items)

      # Group imports by subject ID so you will have one ADD batch for every set of specimens owned by the same patient

      all_items.map{|e| e.subject_id}.uniq.shuffle.each do |sid|

        # Import this block of specimens by subject_id
        $LOG.debug "Filtering by subject_id==#{sid}"
        subset = all_items.select{|e| e.subject_id == sid}


        # Pre-import hooks
        primed_subset = setup( subset )

        # yield to the app for validation
        yield primed_subset

        # Post-import hooks
        begin
          teardown
        rescue RuntimeError
          puts "#{@batch_id} failed"
        end

      end

    end

    def setup(items, options={})

      $LOG.debug """Attempting to prep specimen set: #{items.to_yaml}
      """
      # Setup batch_properties
      batch_properties = {
        'batch.repos_id'      => CONFIGS[:job_attributes][:repos_id]
      }

      # Create batch
      @batch_id = @bsi.batch.create('A', batch_properties)
      @batch = Array.new
      $LOG.info "Empty batch #{@batch_id} created"

      # Find out how many seminal parents there are
      num_seminal_parents = items.select{|s| ['N/A', ''].include?( s.parent_id )}.length

      $LOG.debug "#{num_seminal_parents} seminal parents, reserving #{num_seminal_parents} BSI ID's"

      # Reserve Sample ID's for all the seminal parent's
      # Returns and array of strings with both the sampleID and the sequence number in the format: AAA000000 0000
      fails = 0
      begin
        @seminal_parent_pool = @bsi.batch.reserveAvailableBsiIds( @batch_id, 'LAA000000', num_seminal_parents ).map{|i| i[0..-6]}
      rescue NoMethodError
        fails += 1
        $LOG.debug "reserveAvailableBsiId's returned Nil, retry number #{fails}"
        retry if fails < 3
      end

      # Iterate over the batch and update BSI ID's and Parent ID's
      add_bsi_ids( items )
    end

    def add(s)

      @batch << s

    end

    def teardown(options={})

      options.merge(@options)
      go = ->(bsi, batch, batch_id, options={}) do
        # Add specimens to the created batch
        unless batch.empty?

          # push batch to BSI
          bsi.batch.addVials( batch_id, batch )

          # Fetch batch we allegedly just pushed
          delivered_batch = bsi.batch.get(batch_id)

          # TODO: Make sure all specimens from the ruby batch got added.
          $LOG.debug "Completed batch upload properties: #{delivered_batch['properties'].to_yaml}"

          $LOG.info "Specimens added successfully"

          # Make a quick list of all the vials added with nil attributes excluded
          specimen_summary = Array.new
          if delivered_batch['vials']
            summary = delivered_batch['vials'].each do |hash|
              specimen_summary << hash.select{|k,v| !v.nil? }
            end
          end

          # Run BSI's built in batch checking tools to verify data is ready to be pushed
          l1 =  bsi.batch.performL1Checks( batch_id )
          l2 =  bsi.batch.performL2Checks( batch_id )


          # Commit Batch if it passes all checks

          if l1.nil? && l2.nil?
            if options[:commit]
              bsi.batch.commit( @batch_id )
            else
              puts "Not committing because flag not set in config"
            end
          else
            ap l1 unless l1.nil?
            ap l2 unless l2.nil?
            raise "Edit Check Failure L1:L2 (#{!l1.nil?}:#{!l2.nil?})"
          end

        else
          $LOG.info "Batch #{ @batch_id } didn't have any specimens in it, can't upload"
        end
      end

      unless @options[:lazy]
        go.call @bsi, @batch, @batch_id, options
      else
        Resque.enqueue(LazyImport, go, @bsi, @batch, @batch_id, options)
      end

    end

    def add_bsi_ids( gathering )

      $LOG.debug """ Working with gathering:#{gathering.to_yaml}
      """
      fluid_types   = %w( mnc plasma serum csf buffy\ cells whole\ blood )
      tissue_types  = %w( tissue ffpe slide)

      new_batch = Array.new

      # grab all seminal parents
      seminal_parents = gathering.select{|s| ['N/A', ''].include?(s.parent_id)}


      # Handle fluid differently, since they are almost always orphan specimens
      fluids = seminal_parents.select{ |sp| fluid_types.include?(sp.type) }
      vacutainer_types = fluids.map{|f| f.vacutainer}.uniq

      fluid_types.each do |fluid_type|
        $LOG.debug "Selecting #{fluid_type}"
        fluids_by_type = fluids.select{ |specimen| specimen.type.match(/#{fluid_type}/i)}

        # subselect by specimen type
        vacutainer_types.each do |vac_type|
          $LOG.debug "Subselecting #{fluid_type} specimens by #{vac_type}"
          family = fluids_by_type.select{|specimen| specimen.vacutainer == vac_type}

          unless family.empty?

            # Orphan family identified, assign all specimens the same sample id
            family_sample_id = @seminal_parent_pool.pop

            $LOG.debug """
            Popped sample ID: #{family_sample_id}, assigning it to:#{family.to_yaml}
            """

            sequence = 1
            family.each do |child|
              child.sample_id = family_sample_id
              child.seq_num = "%04d" % sequence
              child.bsi_id  = "#{child.sample_id} #{child.seq_num}"
              child.parent_id = ''

              sequence += 1

              new_batch << child
            end #family.each do

          end #unless family.empty

        end #vacutainer.each do

      end #fluid_types.each do

      # For each top tissue parent, find all descendants
      seminal_tissue_parents = seminal_parents.select{|sp| tissue_types.include?( sp.type ) }

      seminal_tissue_parents.each do |sp|


        sp.sample_id = @seminal_parent_pool.pop
        sp.seq_num   = '0000'
        sp.parent_id = ''

        sp_family, seq = update_descendants( gathering, sp, 1)

        new_batch << sp
        new_batch.concat( sp_family )

      end

      new_batch
    end

    def update_descendants( descendants, parent, seq )

      family = Array.new

      current_children = descendants.select{|s| s.parent_id == parent.current_label}
      $LOG.debug "Parent: #{parent.to_yaml}"
      $LOG.debug "Children: #{current_children.to_yaml}"

      current_children.each do |child|
        $LOG.debug "Parent BSIID: #{parent.bsi_id}"
        $LOG.debug "Child BSIID: #{child.bsi_id}"
        child.sample_id = parent.sample_id
        child.seq_num = '%04d' % seq
        child.parent_id = "#{parent.sample_id} #{parent.seq_num}"

        seq += 1

        family << child

        # Check if this child has children
        child_family = descendants.select{|s| s.parent_id == child.current_label}
        $LOG.debug "Current Child: #{child.current_label}'s family: #{child_family.to_yaml}"

        unless child_family.empty?
          childs_new_fam, seq = update_descendants( descendants, child, seq )
          $LOG.debug "Childs updated family:#{childs_new_fam.to_yaml}"
          family.concat( childs_new_fam )
        end

      end

      return family, seq
    end

    def terminate
      @bsi.common.logoff
      nil
    end

  end
end
