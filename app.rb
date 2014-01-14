require 'sinatra'
require 'haml'

class Blink < Sinatra::Application
  enable :sessions

  configure :production do
    # ...

  end

  configure :development do
    # ...
  end

  helpers do
    # ...
  end

end

require_relative 'routes/init'
# require_relative 'sinatra/helperst'
