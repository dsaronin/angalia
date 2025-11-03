#!/bin/bash

# ==============================================================================
# Angalia Kiosk Session Automation Script (Linux Mint)
# Designed for Daudi's machines (jabari and akili) using NetworkManager and Chrome.
# This script automates VPN connection, checks kiosk status, launches Jitsi,
# triggers the Kiosk START/END actions, and handles VPN disconnection.
# ==============================================================================

# --- Configuration Variables ---
ANGALIA_HUB="http://angalia-hub:8080"
JITSI_URL="https://jitsi.vpn.local/angalia"
HUB_CONFIRM_URL="${ANGALIA_HUB}"
HUB_START_URL="${ANGALIA_HUB}/start_meet"
HUB_END_URL="${ANGALIA_HUB}/end_meet"
BROWSER_CMD="/usr/bin/google-chrome" # Confirmed path

# --- Host and VPN Configuration ---
HOST=$(hostname)
VPN_CONN_NAME=""

if [ "$HOST" = "jabari" ]; then
    # Assumes NetworkManager connection ID is named 'rufiji-client'
    VPN_CONN_NAME="rufiji-client"
elif [ "$HOST" = "akili" ]; then
    # Assumes NetworkManager connection ID is named 'msimbazi-client'
    VPN_CONN_NAME="msimbazi-client"
else
    echo "ERROR: Unknown host '$HOST'. This script is restricted to 'jabari' or 'akili'."
    exit 1
fi

# --- Function Definitions ---

# Function to connect the OpenVPN tunnel via NetworkManager
vpn_connect() {
    echo "1. Attempting to start VPN connection: ${VPN_CONN_NAME}..."

    # Check if connection is already active
    if nmcli con show --active | grep -q "${VPN_CONN_NAME}"; then
        echo "   >> VPN is already active."
        return 0
    fi

    # Attempt to connect (nmcli con up is synchronous by default)
    if nmcli con up id "${VPN_CONN_NAME}"; then
        echo "   >> VPN connection established."
        return 0
    else
        echo "   >> ERROR: Failed to establish VPN connection '${VPN_CONN_NAME}'. Aborting."
        return 1
    fi
}

# Function to disconnect the OpenVPN tunnel via NetworkManager
vpn_disconnect() {
    echo "8. Disconnecting VPN connection: ${VPN_CONN_NAME}..."
    if nmcli con down id "${VPN_CONN_NAME}"; then
        echo "   >> VPN disconnected successfully."
    else
        echo "   >> WARNING: Failed to disconnect VPN. Please do this manually."
    fi
}

# --- Script Execution Start ---

echo "--- Angalia Kiosk Session Automation (Running on $HOST) ---"

# Step 1: Start VPN Connection
if ! vpn_connect; then
    exit 1 # Exit if VPN connection failed
fi

# Wait briefly for the tunnel to stabilize before running curl
sleep 3

# Step 2: Confirm angalia-hub is running
echo "2. Pinging angalia-hub for server confirmation..."
if curl --fail --silent --output /dev/null "$HUB_CONFIRM_URL"; then
    echo "   >> angalia-hub is responsive."
else
    echo "   >> ERROR: angalia-hub is unreachable over VPN."
    vpn_disconnect
    exit 1
fi

# Step 3: Open Jitsi Meeting Window (Single Window)
echo "3. Opening Jitsi Meet in Chrome..."
"${BROWSER_CMD}" --new-window "${JITSI_URL}" &
BROWSER_PID=$! # Note: This PID is often for the wrapper, not the running Chrome process.

# Wait 2 seconds for the browser to open and begin loading the Jitsi page
sleep 2

echo ""
echo "--- SESSION ACTIVE ---"
echo ""

# Step 4: Trigger ANGALIA-HUB/start_meet [GET]
echo "4. Sending START trigger to Angalia Kiosk..."
if curl --fail --silent "$HUB_START_URL"; then
    echo "   >> Kiosk session initiated successfully. Monitor will turn on."
else
    echo "   >> ERROR sending START trigger. The Kiosk may not have joined."
fi

# --- SESSION WAIT (Caregiver signals end) ---

echo "Status: Meeting started. Kiosk is connected."
echo "Action: When your VIDEO session is finished..."
echo "-- FIRST: click the RED 'END MEETING FOR EVERYBODY' in Jitsi Meeting (accessed by clicking red phone icon in lower part of meeting window)."
echo "-- this will end the meeting for everybody,"
echo "-- THEN return here to this terminal and..." 
# Step 5: (Manual) MODERATOR clicks END MEETING FOR EVERYBODY (User Action)

read -p "...press [ENTER] to proceed to close the Kiosk connection."

# Step 6: Trigger ANGALIA-HUB/end_meet [GET]
echo "6. Sending END trigger to Angalia Kiosk..."
if curl --fail --silent "$HUB_END_URL"; then
    echo "   >> Kiosk session ended. Monitor should now turn off."
else
    echo "   >> ERROR sending END trigger."
fi

# Step 7 (Implicit): Close all open windows (Manual)
echo "7. Please manually close the open Jitsi browser window."

# Step 8: Disconnect VPN connection (Automated)
vpn_disconnect

echo "--- Session Script Complete ---"

