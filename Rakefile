require 'bundler/setup'
require_relative 'app'
require 'resque/tasks'

task "resque:setup" do
  ENV['QUEUE'] = '*'
end

desc "alias for resque:work (to run workers on heroku)"
task "jobs:work" => "resque:work"
