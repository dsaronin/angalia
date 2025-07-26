# config.ru

require 'sinatra'
require_relative './app/angalia_app'
require_relative './app/angalia_work'

configure do
  ENV['SINATRA_ENV'] ||= "development"
  ENV['RACK_ENV']    ||= "development"

  ANGALIA = Angalia::AngaliaWork.new 
  ANGALIA.setup_work()    # initialization of everything

  PUBLIC_DIR = File.join(File.dirname(__FILE__), 'public')
  set :public_folder, PUBLIC_DIR
  set :root, File.dirname(__FILE__)
  set :haml, { escape_html: false }
  set :session_secret, '748110627dfc29efde83c90c7a1e689b8dc8e4c21033345e91764f4b4c98443395ee5e96418443011ac588e7ca77fb1a26b172223b5875f3108ef7b4ec8124f3'

  Angalia::Environ.log_info  "PUBLIC_DIR: #{PUBLIC_DIR}"
  Angalia::Environ.log_info  "configuring Angalia application"

end  # configure

run Angalia::AngaliaApp


# notes
# thin -R config.ru -a 127.0.0.1 -p 8080 start
#
# http://localhost:8080/
# curl http://localhost:8080/ -H "My-header: my data"

