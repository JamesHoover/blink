require 'sinatra/base'
require 'ap'
require './sinatra/basic.rb'
require './sinatra/search.rb'
require './sinatra/mutations.rb'
LIBS = `find . | grep ./sinatra/ | grep -v helpers.rb | grep -v .swp`.split(/\n/)

module Sinatra

  libs = LIBS.map{ |s| s.slice(/^.\/sinatra\/(.+)\.rb$/, 1) }.map{|s| s.capitalize}
  # load helper files
  instance_eval("helpers #{libs.join(',')}")
end
