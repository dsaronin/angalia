#!/bin/bash
#
# Source RVM to enable RVM commands and environment
# This is for a single-user RVM installation (most common for user setups)
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

# Navigate to the application directory
cd /home/angalia-hub/projects/angalia || { echo "Failed to change directory to /home/angalia-hub/projects/angalia" >&2; exit 1; }

# Use the specific Ruby version and gemset
# This ensures the correct environment is active for bundle exec
rvm use ruby-3.2.2@angalia

# Set environment variables for the application
export RACK_ENV="production"
export SINATRA_ENV="production"
export DEBUG_ENV="false"
export SKIP_HUB_VPN="false"
export VPN_TUNNEL_ENV="false"

# Define log file path
LOG_FILE="/home/angalia-hub/log/angalia_hub.log"

# Ensure the log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Get current date and time in YYYYMMDD-HHMMSS format
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Extract base name and extension from the log file path
LOG_BASENAME="${LOG_FILE%.*}" # Removes the last dot and everything after it
LOG_EXTENSION=".${LOG_FILE##*.}" # Extracts the extension including the dot

# Check if the log file exists and rename it
if [ -f "$LOG_FILE" ]; then
    mv "$LOG_FILE" "${LOG_BASENAME}-${TIMESTAMP}${LOG_EXTENSION}"
    echo "Renamed existing log file to ${LOG_BASENAME}-${TIMESTAMP}${LOG_EXTENSION}"
fi

# Start the Thin server in the background, redirecting stdout and stderr to the log file.
# nohup ensures the process continues running even if tty is closed.
# bundle exec ensures all gems from the Gemfile are loaded correctly.
nohup bundle exec thin -R config.ru -a 0.0.0.0 -p 8080 start >> "$LOG_FILE" 2>&1 &

echo "Angalia-hub started. Check logs at $LOG_FILE"
