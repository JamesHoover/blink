require 'sinatra/base'
require 'ap'
LIBS = `find . | grep ./sinatra/ | grep -v helpers.rb | grep -v .swp`.split(/\n/)
LIBS.each{|lib| instance_eval("require '#{lib}'")}

module Sinatra

  libs = LIBS.map{ |s| s.slice(/^.\/sinatra\/(.+)\.rb$/, 1) }.map{|s| s.capitalize}
  # load helper files
  instance_eval("helpers #{libs.join(',')}")
end
