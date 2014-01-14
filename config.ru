require 'sinatra'
require './app.rb'

root = ::File.dirname(__FILE__)
require ::File.join( root, 'app' )
run Blink.new
