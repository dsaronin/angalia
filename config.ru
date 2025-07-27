# config.ru

require 'sinatra'
require_relative './app/angalia_app'
require_relative './app/angalia_work'

configure do
  ENV['SINATRA_ENV'] ||= "development"
  ENV['RACK_ENV']    ||= "development"
  ENV['DEBUG_ENV']    ||= true
  ENV['VPN_TUNNEL_ENV']  ||= false

  ANGALIA = Angalia::AngaliaWork.new 
  ANGALIA.setup_work()    # initialization of everything

  PUBLIC_DIR = File.join(File.dirname(__FILE__), 'public')

  set :public_folder, PUBLIC_DIR
  set :root, File.dirname(__FILE__)
  set :haml, { escape_html: false }
  set :session_secret, ENV['ANGALIA_TOKEN'] 

  Angalia::Environ.log_info  "Config: Configuring Angalia application"
  Angalia::Environ.log_info  "Config: PUBLIC_DIR: #{PUBLIC_DIR}"
  Angalia::Environ.log_info  "Config: Env=Sinatra: #{ENV['SINATRA_ENV']}, Rack: #{ ENV['RACK_ENV']}, Debug: #{ENV['DEBUG_ENV']}, VPN: #{ENV['VPN_TUNNEL_ENV']}"

end  # configure

run Angalia::AngaliaApp


# notes
# thin -R config.ru -a 127.0.0.1 -p 8080 start
#
# http://localhost:8080/
# curl http://localhost:8080/ -H "My-header: my data"

