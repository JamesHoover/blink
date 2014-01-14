
module Parser
  require 'roo'
  require 'csv'
  require CONFIGS[:model]

  # Monkey patch Symbol so we can use methods in case/when
  class Symbol
    alias :original_triple_equals :"==="

    def ===(object)
      original_triple_equals(object) ||
        (object.respond_to?(self) && object.__send__(self))
    end

  end

  # Set this up so it can feed next available coordinates in a 9x9 box
  class DummyBox
    attr_accessor :row, :col, :vector

    def initialize(options={})
      @row = options[:rows]
      @col = options[:cols]
      @vector = @col.product(@row).map!{|a| a.join('')}
    end

    def next_slot
      @vector.shift
    end

  end

  def parse(file_path)

    @specimens = Array.new

    # build in memory specimen lookup table here based on jeremy's freezer spreadsheet data
    @location_map = YAML::load(File.open(CONFIGS[:location_map_path]))
    @dummy_boxes = {}
    counter = 1
    CSV.foreach(file_path, :headers => true) do |csv|
      s = Specimen.new
      print "Reading row: #{counter}                 \r"

      s.billing_method  = 'Purchase Order'
      s.label_status    = 'Barcoded'

      s.current_label   = csv['sample_id'].to_i.to_s
      s.subject_id      = csv['case_id']
      s.protocol        = csv['protocol_normalized']
      s.ian             = csv['surgery_number_normalized'].to_s
      s.ian_part        = csv['surgery_number_part_normalized'].to_s
      s.type            = csv['sample_type'].to_s

      case s.type
      when /ffpe/i
        s.fixative = '10% NBF'
      when /slide/i
        s.fixative = '10% NBF'
      else

      end

      case csv['collection_container']
      when /vacutainer/i
        s.vacutainer    = csv['container_additive']
      else
      end

      s.date_received   = csv['sample_date']
      s.date_drawn      = s.date_received
      s.stain_type      = csv['histo_stain']
      s.parent_id       = csv['parent_id_normalized']

      s.measurement     = csv['aliquot_volume'].to_i.to_s
      s.measurement_unit= 'ml'

      s.box             = csv['box_id'].to_i.to_s
      slot_location     = csv['slot_location'].to_s
      unless slot_location.match(/^[A-I]{1}\d$/i)

        # Check to see if we've already put a specimen in that box, if not add one
        unless @dummy_boxes.has_key?(s.box)
          dummy_box = nil
          if s.type.match(/(ffpe|slide)/)
            dummy_box = DummyBox.new( {
              :rows => (1..400).to_a,
              :cols => ('A'..'C').to_a
            } )
          else
            dummy_box = DummyBox.new( {
              :rows => (1..9).to_a,
              :cols => ('A'..'I').to_a
            } )
          end
            @dummy_boxes.store( s.box, dummy_box )
        end
        slot_location = @dummy_boxes[s.box].next_slot
      end

      next unless s.box =~ /\d{6}/ && @location_map.keys.include?(s.box)

      s.building        = @location_map[s.box][:building]
      s.room            = @location_map[s.box][:room]
      s.freezer         = @location_map[s.box][:freezer].to_s
      s.shelf           = @location_map[s.box][:shelf]
      s.rack            = @location_map[s.box][:rack]

      s.col             = slot_location[0]
      s.row             = slot_location[1]

      @specimens << s

      counter += 1

    end

    @specimens.uniq{|s| s.current_label}
  end

  def generate_location_map(map_path)

    rgx = /([0-9]{6})/
    xls = Excel.new(map_path)
    srr, match = nil
    2.upto(xls.last_row).each do |row|
      srr = xls.cell(row, 1)
      2.upto(5).each do |col|
        match = xls.cell(row, coll)
        box = nil
      end
    end

  end

end
