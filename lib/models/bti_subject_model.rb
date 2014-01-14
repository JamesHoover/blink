require './subject.rb'
require CONFIGS[:formatter]

class Model < Subject
  include Formatter
end
