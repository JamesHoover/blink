module Importer
  require 'rbc'
  require './lib/importers/importer_base.rb'

  class Pipe < ImporterBase

    def initialize(key, options={})
      debug = options[:debug]
      @bsi = RBC.new(key, debug)
    end

    def import(s)
      ap s
    end

  end
end
