require 'awesome_print'
require 'rbc'
require 'forwardable'
require 'logger'

# Load Configs
BASE_CONFIGS  = YAML::load(File.open('./spec.yaml'))
ENV_CONFIGS   = YAML::load(File.open('./env.yaml'))
job_configs   = {}
job_configs   = YAML::load(File.open(BASE_CONFIGS[:run_config])) if BASE_CONFIGS[:run_config]
CONFIGS       = BASE_CONFIGS.merge(job_configs).merge(ENV_CONFIGS)


require CONFIGS[:model]
require CONFIGS[:parser]
require CONFIGS[:importer]

class Handler

  include Resque::Plugins::Status if CONFIGS[:resque]

  # Mixin added functionality
  include Parser
  include Importer
  extend Forwardable

  attr_accessor :piper
  def_delegators :@piper, :import, :add

  def startup

    # Initialize logger
    log_dir   = CONFIGS[:logging][:log_dir]
    log_name  = CONFIGS[:logging][:log_name]
    shift_age = CONFIGS[:logging][:log_shift_age]

    # Initialize Logger
    $LOG = Logger.new("#{log_dir}/#{log_name}", shift_age)

    $LOG.info "CONFIGS for current job: #{ CONFIGS }"
    key = YAML::load( File.open(CONFIGS[:key_path]))

    $LOG.info "Initializing Importer..."
    @piper = Pipe.new(key, {}.merge(CONFIGS[:import_options]))

    $LOG.info "Handler Initialized"

    # Method thats run once before a job, used to grab metadata from BSI and populate configurations
    # TODO: expand this to grab intent of columns added by BSI customization module
    # by looking up shortnames and adding auto-patching fields in the specimen model.
    # These fields normally have the form vial.field_xxx
    #
    #
    #

    unless CONFIGS[:import_options][:stealth]
      vial_props = @piper.call('batch.getVialProperties').grep(/vial/)
      export = Array.new
      vial_props.each do |prop|
        valid_prop = prop.match(/^vial\.(.+)$/)
        if valid_prop
          export << $1
        end
      end
      File.open('./config/vial_props.yaml', 'w') do |f|
        f.write(export.to_yaml)
      end
    end

  end

  def shutdown
    @piper.terminate
    $LOG.info "Import Job Completed Successfully"
    puts "Job finished Successfully"

    nil
  end

  def run

    # Check temp directory for buffering path defined
    if CONFIGS[:temp_yaml_path]
      @buffer_dir   = "#{CONFIGS[:temp_yaml_path]}/"
      @buffer_file  = "#{CONFIGS[:project_name]}.yaml"
      @item_buffer_path = @buffer_dir + @buffer_file

      # Check if there's already a file
      if FileTest.exists?( @item_buffer_path )

        # Oh look, a cache file, lets import it
        $LOG.info "Loading cache file from #{ @item_buffer_path }"
        @items = YAML::load(File.open( @item_buffer_path ))

      else
        # No cache file exists, import spreadsheet with caching
        $LOG.info "No cache file exists"
        $LOG.info "Parsing #{CONFIGS[:file_path]}"
        @items = parse(CONFIGS[:file_path])

        File.open(@item_buffer_path, 'w') do |f|
          f.write(@items.to_yaml)
        end
      end

    else
      # No buffer target directory defined, parse spreadsheet without cacheing
      $LOG.info "Parsing #{CONFIGS[:file_path]}"
      @items = parse(CONFIGS[:file_path])
    end

    unless @items.empty?

      num = 0
      total = @items.length

      # Pass import all the items you want and it will get back 1 or many sets of items that need imported
      import(@items.shuffle) do |items|

        num +=items.length
        # Make sure every item is valid before importing
        items.each do |item|

          if item.valid?

            $LOG.info "importing #{item.type} with label: #{item.current_label}"

            add(item.to_bfh.merge(CONFIGS[:item_attributes]))

          else
            $LOG.info "Item #{item.current_label} invalid because its missing #{item.missing_attrs.join(', ')}therefore not adding"
          end # if item.valid?
        end # items.each do

        at(num, total, "Currently at #{num} of #{total}")
      end # import(@items) yield block

    else
      $LOG.debug "No items returned by the parser"
    end

  end

  def perform
    startup
    run
    shutdown

    # Called for Resque::Plugins::Status
    completed
  end

end

# If running from command line...
if __FILE__==$0
  job = Handler.new
  job.startup
  job.run
  job.shutdown
end
