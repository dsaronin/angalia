# config.ru

require 'sinatra'
require_relative './app/angalia_app'
require_relative './app/angalia_work'

configure do
  ENV['SINATRA_ENV'] ||= "development"
  ENV['RACK_ENV']    ||= "development"
  ENV['DEBUG_ENV']    ||= true.to_s  # true if DEBUG mode
  ENV['VPN_TUNNEL_ENV']  ||= false.to_s  # future
  ENV['SKIP_HUB_VPN']  ||= false.to_s   # true if SKIP malagarasi-client vpn connect

# --------------------------------------------------
  # Check system dependencies only in the "development" environment
  # If pkgcheck.sh returns a non-zero exit status (failure), abort startup.
  if ENV['SINATRA_ENV'] == "development"
    unless system("./pkgcheck.sh")
      warn "ERROR: Required system packages are missing or not found in PATH."
      warn "Please review the output of ./pkgcheck.sh for details on missing dependencies."
      abort "Aborting application startup due to missing system dependencies."
    end
  end

# --------------------------------------------------
# system environment confirmed; start application
# --------------------------------------------------
  ANGALIA = Angalia::AngaliaWork.new 
  ANGALIA.setup_work()    # initialization of everything

  PUBLIC_DIR = File.join(File.dirname(__FILE__), 'public')

  set :public_folder, PUBLIC_DIR
  set :root, File.dirname(__FILE__)
  set :haml, { escape_html: false }
  set :session_secret, ENV['ANGALIA_TOKEN'] 

  Angalia::Environ.log_info  "Config: Configuring Angalia application"
  Angalia::Environ.log_info  "Config: PUBLIC_DIR: #{PUBLIC_DIR}"
  Angalia::Environ.log_info  "Config: Env=Sinatra: #{ENV['SINATRA_ENV']}, Rack: #{ ENV['RACK_ENV']}, Debug: #{ENV['DEBUG_ENV']}, SKIP: #{ENV['SKIP_HUB_VPN']}, VPN: #{ENV['VPN_TUNNEL_ENV']}"

end  # configure

run Angalia::AngaliaApp


# notes
# thin -R config.ru -a 0.0.0.0 -p 8080 start
#
# http://localhost:8080/
# curl http://localhost:8080/ -H "My-header: my data"

