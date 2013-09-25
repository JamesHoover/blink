require 'yaml'
require 'tire'
require 'awesome_print'

class SendToES
  def run!

    require './specimen.rb'
    protocol_directory = ARGV[0]
    raise 'no protocol directory provided' if protocol_directory.nil?
      to_elastic(protocol_directory)

  end

  def process_yaml(protocol_file)
    puts "Importing #{protocol_file}"

    file = YAML::load( File.open(protocol_file) )

    puts "mapping slides"
    slides = file[:slides].map do |slide|
      spec = slide.to_hash
      marker_type = 'biomarker'
      marker_type = 'stain' if spec[:marker_name].to_s === 'HE'
      spec.store(:_marker_type,marker_type)
      spec.store(:type,'specimen')
      spec.store(:_specimen_type, 'slide')
      spec.store(:_short_list, ['label', 'protocol', 'case_number', 'marker_name'])
      spec.store(:_id, slide.id)
      spec.store(:_pif_val, slide.id)
      spec.store(:_pif_name, 'label')
      spec
    end

    puts "mapping cases"
    cases = file[:slides].collect{|e| e.case_id.to_s}.uniq.map do |specimen|
      kase = Hash.new
      kase.store(:case_number, specimen)
      kase.store(:protocol, slides.first[:protocol] )
      kase.store(:type, 'subject')
      kase.store(:_short_list, ['protocol', 'case_number'])
      kase.store(:_pif_val, specimen)
      kase.store(:_pif_name, 'case_number')
      kase
    end

    puts "mapping blocks"
    blocks = file[:blocks].map do |block|

      blk = block.to_hash
      blk.store(:type, 'specimen')
      blk.store(:_id, block.id)
      blk.store(:_specimen_type, 'block')
      blk.store(:_short_list, ['label', 'protocol', 'case_number'])
      blk.store(:_pif_val, block.id)
      blk.store(:_pif_name, 'label')
      blk

    end

    data = {:slides => slides, :cases => cases, :blocks => blocks}
  end

  def to_elastic(protocol_directory, control_file=nil)
    controls = Array.new
    Tire.index 'bsi' do
      delete
      create
    end

    yamls = `find #{protocol_directory} | grep .yaml `.split(/\n/)

    yamls.each do |yaml_file|
      data = process_yaml(yaml_file)

      unless control_file.nil?
        puts "loading controls from #{control_file}"
        controls = load_cuntrols(control_file)
        data.store(:slides, data[:slides].concat(controls) )
      else
        puts "No controls given"
      end

      Tire.index 'bsi' do
        data.each do |name, values|
          puts "importing #{name}"
          import values
        end
        refresh
      end
    end
  end

end

SendToES.new.run! if __FILE__==$0
