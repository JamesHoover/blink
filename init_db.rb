require './lib/specimen.rb'
require './lib/to_elastic2.rb'

test_data = './test/TEST.yaml'

SendToES.new.to_elastic(test_data)
