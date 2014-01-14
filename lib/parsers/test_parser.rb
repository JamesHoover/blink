require 'awesome_print'
require './pacct_parser.rb'

class Test
  include Parser
end
Test.new.parse('../../data/PACCT_subjects.csv')
