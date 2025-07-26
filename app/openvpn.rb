# --- openvpn.rb ---
# Angalia: OpenVPN Connection Management Singleton
# Copyright (c) 2025 David S Anderson, All Rights Reserved

require 'singleton'
require_relative 'environ' # Required for Environ.log_info, Environ::OPENVPN_CLIENT_CONFIG_PATH, Environ::VPN_RETRY_COUNT
require_relative 'angalia_error' # Required for AngaliaError::OpenVPNError

# +++++++++++++++++++++++++++++++++++++++++++++++++
module Angalia              # Define the top-level module  
# +++++++++++++++++++++++++++++++++++++++++++++++++

class OpenVPN
  include Singleton

  def initialize
    verify_configuration(false) # make sure client vpn service started
    # NOTE: does NOT establish vpn tunnel here.
  end

  # ------------------------------------------------------------
  # verify_configuration -- Ensures the OpenVPN service is running
  # args:
  #   connect -- true if verify_configuration should also connect the tunnel
  # This is the primary entry point for OpenVPN setup.
  # Attempts to start the OpenVPN client systemd service.
  # Raises AngaliaError::OpenVPNError if the connection cannot be established or verified.
  # ------------------------------------------------------------
  def verify_configuration( connect )
    begin
      unless system("systemctl is-active NetworkManager.service > /dev/null 2>&1")
        raise AngaliaError::OpenVPNError.new("NetworkManager.service is not active. nmcli commands will not work.")
      end
      Environ.log_info("OpenVPN: Verified NetworkManager.service running.")

      unless !connect  # try to connect if requested
        if connect_vpn_tunnel  # try establish tunnel
          # SUCCESS IS HERE
          Environ.log_info("OpenVPN: Angalia vpn tunnel connected.")
        else  # FAILURE IS HERE
          Environ.log_error("OpenVPN: Angalia vpn tunnel does NOT connect.")
          raise AngaliaError::OpenVPNError.new("Angalia vpn tunnel does NOT connect.")
        end
      end   #  unless connection try

      # rescue block =========================================================
    rescue AngaliaError::OpenVPNError => e
      raise
    rescue => e
      msg = "OpenVPN: Unexpected error during service start: #{e.message}"
      Environ.log_error(msg)
      raise AngaliaError::OpenVPNError.new(msg)
    end
      # end rescue block ======================================================
  end # verify_configuration

  # ------------------------------------------------------------
  #  start_vpn -- verifies services, connects tunnel
  #  this will be the entry point each time that a MEETING is started
  # Raises AngaliaError::OpenVPNError if the connection cannot be established or verified.
  # Raises AngaliaError::OpenVPNError if tunnel fails
  # ------------------------------------------------------------
  def start_vpn
    verify_configuration( true )  
  end

  # ------------------------------------------------------------
  # establish_tunnel -- Executes the OpenVPN client command to try and bring up the tunnel.
  # This method assumes it might be called with sudo privileges.
  # It does NOT verify the tunnel's active state; that's done by vpn_connected?.
  # Returns:
  #   boolean: true if the command was successfully executed, false otherwise.
  # ------------------------------------------------------------
  def establish_tunnel
    command = "nmcli connection up #{Environ::ANGALIA_VPN_CLIENT}"
    return system(command)
  end # establish_tunnel

  # ------------------------------------------------------------
  # vpn_connected? -- Checks if the OpenVPN tunnel is active.
  # Returns:
  #   boolean: true if the tunnel process is found, false otherwise.
  # ------------------------------------------------------------
  def tunnel_connected?
    command = "nmcli connection show #{Environ::ANGALIA_VPN_CLIENT} | grep -i 'vpn connected' > /dev/null 2>&1"
    return system(command)
  end # vpn_connected?

  # ------------------------------------------------------------
  # connect_vpn_tunnel -- Attempts to connect the VPN tunnel with retries.
  # Assumes OpenVPNclient service is running.
  # returns: state of tunnel_connected?  t if connected
  # ------------------------------------------------------------
  def connect_vpn_tunnel
    countdown = Environ::VPN_RETRY_COUNT

    while ( !(state = tunnel_connected?) && (countdown -= 1) >=0 )
      establish_tunnel # Start the tunnel
      sleep Environ::VPN_SLEEP_COUNT  # wait for VPN tunnel
    end  # while establishing tunnel

    return state

  end # connect_vpn_tunnel

  # ------------------------------------------------------------
  # disconnect_vpn_tunnel -- Disconnects the OpenVPN tunnel.
  # ------------------------------------------------------------
  def disconnect_vpn_tunnel
    command = "nmcli connection down #{Environ::ANGALIA_VPN_CLIENT}"
    system(command) if tunnel_connected?
  end # disconnect_tunnel

  # ------------------------------------------------------------
  # ------------------------------------------------------------
end  # Class OpenVPN

end  # module Angalia

