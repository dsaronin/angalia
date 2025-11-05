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
LOG_DIR="/home/angalia-hub/log"
LOG_FILE="$LOG_DIR/angalia_hub.log"
PUMA_PID_FILE="$LOG_DIR/angalia_hub_puma.pid"

# Ensure the log directory exists
mkdir -p "$LOG_DIR"

# --- Log Rotation ---
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

# --- PID Lock Check ---
# This check prevents a double-launch of the puma server.
if [ -f "$PUMA_PID_FILE" ]; then
    OLD_PID=$(cat "$PUMA_PID_FILE")
    # Check if the process ID from the file is still running
    if ps -p "$OLD_PID" > /dev/null; then
        # Echo to stdout since log file is new
        echo "[ $(date +"%Y-%m-%d %H:%M:%S %Z") ] ANGALIA ERROR: Puma server is already running with PID $OLD_PID (from $PUMA_PID_FILE). Aborting."
        exit 1 # Abort script
    else
        # The process is not running, so the PID file is stale
        echo "[ $(date +"%Y-%m-%d %H:%M:%S %Z") ] ANGALIA WARN: Found stale PID file for $OLD_PID. Removing $PUMA_PID_FILE."
        rm "$PUMA_PID_FILE"
    fi
fi

# --- Start Puma Web Server ---
# nohup ensures the process continues running.
# '>> "$LOG_FILE" 2>&1 &' handles logging/daemonization and respects rotation.
nohup bundle exec puma -C config/puma.rb >> "$LOG_FILE" 2>&1 &

echo "Angalia-hub started. Check logs at $LOG_FILE"
