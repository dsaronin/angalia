# Set the port to listen on (8080 for angalia-hub)
port 8080

# Set the environment
environment ENV.fetch("RACK_ENV") { "production" }

# Specify the PID file
pidfile '/home/angalia-hub/log/angalia_hub_puma.pid'

# Load the rackup file (config.ru)
rackup '/home/angalia-hub/projects/angalia/config.ru'

# NOTE: stdout/stderr redirection is intentionally not handled here.
# It is handled by the shell in 'start_angalia.sh'
# to preserve your log rotation logic.
