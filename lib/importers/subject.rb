require './lib/importers/importer_base.rb'
module Importer
  require 'rbc'

  class Pipe < ImporterBase

    def initialize(key, options={})
      @bsi = RBC.new(key, options)
    end

    def setup
      nil
    end

    def import(s)

      begin
        exists = @bsi.subject.getSubject(s['subject.study_id'], s['subject.subject_id'])
      rescue RuntimeError => e
        # do nothing, exists should still be nil
        # TODO: log this error
        puts e
      end

      # If it exists update it
      if exists
        puts "Subject already exists in db, checking attribute validity"
        l1_pass = @bsi.subject.performL1Checks(s, s['subject.study_id'], s['subject.subject_id']).nil?
        if l1_pass
          puts "Subject cleared for updating"
          @bsi.subject.saveSubject(s)
        end
      else
        # If not, check if we can create a new one?
        puts "Subject doesn't exist, checking attribute validity"
        l1_pass = @bsi.subject.performL1Checks(s, s['subject.study_id'], s['subject.subject_id'].to_s).nil?
        l2_pass = @bsi.subject.performL2Checks(s, s['subject.study_id'], s['subject.subject_id'].to_s).nil?
        if l1_pass && l2_pass
          puts "Subject cleared for creation"
          @bsi.subject.saveNewSubject(s, s['subject.study_id'], s['subject.subject_id'])
        else
          raise "L1/L2 Errors: #{l1_pass} | #{l2_pass}"
        end
      end

    end

    def teardown
      nil
    end

  end
end
