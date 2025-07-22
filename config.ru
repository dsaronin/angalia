# config.ru

require 'sinatra'
require_relative './app/angalia_app'
require_relative './app/angalia_work'

configure do
  ENV['SINATRA_ENV'] ||= "development"
  ENV['RACK_ENV']    ||= "development"

  ANGALIA = AngaliaWork.new 
  ANGALIA.setup_work()    # initialization of everything

  PUBLIC_DIR = File.join(File.dirname(__FILE__), 'public')
  set :public_folder, PUBLIC_DIR
  set :root, File.dirname(__FILE__)
  set :haml, { escape_html: false }

  Environ.log_info  "PUBLIC_DIR: #{PUBLIC_DIR}"
  Environ.log_info  "configuring DersHocası"

end  # configure

run AngaliaApp


# notes
# thin -R config.ru -a 127.0.0.1 -p 8080 start
#
# http://localhost:3000/
# curl http://localhost:4567/ -H "My-header: my data"

