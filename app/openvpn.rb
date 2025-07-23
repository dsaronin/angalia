# --- openvpn.rb ---
# Angalia: OpenVPN Connection Management Singleton
# Copyright (c) 2025 David S Anderson, All Rights Reserved

require 'singleton'
require_relative 'environ' # Required for Environ.log_info
require_relative 'angalia_error' # Required for AngaliaError::OpenVPNError

class OpenVPN
  include Singleton

  def initialize
    verify_configuration   #  handle the initial check and connection.
  end

  # ------------------------------------------------------------
  # verify_configuration -- Checks OpenVPN connection status and attempts to activate.
  # Raises AngaliaError::OpenVPNError if the connection cannot be established or verified.
  # ------------------------------------------------------------
  def verify_configuration
    Environ.log_info("OpenVPN: Verifying connection and activating if necessary.")
    begin
      # TODO: Replace with actual system calls to check VPN status and connect.
      # Example: Check `systemctl is-active openvpn@client` or parse `ip a` output for tun0.
      # If not active, attempt `sudo systemctl start openvpn@client` or similar.
      # For now, simulate success:
      vpn_active = true # Simulate successful VPN connection

      unless vpn_active
        Environ.log_error("OpenVPN: Connection not active. Attempting to start...")
        # TODO: Add actual command to start VPN, e.g., success = system("sudo systemctl start openvpn@client")
        # For now, simulate success:
        connection_attempt_successful = true # Simulate successful connection attempt

        unless connection_attempt_successful
          raise AngaliaError::OpenVPNError.new("Failed to establish OpenVPN connection.")
        end
      end
      Environ.log_info("OpenVPN: Connection verified successfully.")
    rescue AngaliaError::OpenVPNError => e
      Environ.log_fatal("OpenVPN: Configuration/Connection error: #{e.message}")
      raise # Re-raise for AngaliaWork to handle as a MajorError
    rescue => e
      Environ.log_fatal("OpenVPN: Unexpected error during connection verification: #{e.message}")
      raise AngaliaError::OpenVPNError.new("Unexpected error during OpenVPN verification: #{e.message}") # Wrap unexpected errors
    end
  end # verify_configuration

  # ------------------------------------------------------------
  # ------------------------------------------------------------

end # Class OpenVPN

