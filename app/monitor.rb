# --- monitor.rb ---
#
# Angalia: A Remote Elder Monitoring Hub
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#

require 'singleton'
require_relative 'environ' # Required for Environ.log_info, Environ.my_monitor_default
require_relative 'angalia_error' # Required for MonitorError, MonitorOperationError

# +++++++++++++++++++++++++++++++++++++++++++++++++
module Angalia              # Define the top-level module  
# +++++++++++++++++++++++++++++++++++++++++++++++++

class Monitor
  include Singleton

  def initialize
    @is_on = false
    verify_configuration # Perform configuration check on initialization
  end

  # ------------------------------------------------------------
  # set_display_name_with_fallback -- Attempts to set the monitor name,
  # falling back to default if dynamic discovery fails.
  # This method itself does NOT have exception handling, allowing errors
  # from get_my_monitor to propagate to verify_configuration.
  # ------------------------------------------------------------
  def set_display_name_with_fallback
    Environ.log_info("Monitor: Setting display name...")
    connected_monitors = []
    begin
      connected_monitors = get_my_monitor() # This now returns an array

    rescue MonitorError => e
      Environ.log_warn("Monitor: Dynamic discovery of monitors failed: #{e.message}. Will attempt to use default or fallback logic.")
      # connected_monitors remains empty, which will lead to using the default
    rescue => e
      Environ.log_warn("Monitor: Unexpected error during monitor discovery: #{e.message}. Will attempt to use default or fallback logic.")
      # connected_monitors remains empty
    end

    if connected_monitors.empty?
      @display_name = Environ.my_monitor_default
      Environ.log_warn("Monitor: No connected monitors found or discovery failed. Using default: #{@display_name}.")
    elsif connected_monitors.first != Environ::DEV_MONITOR_DISPLAY_NAME
      @display_name = connected_monitors.first
      Environ.log_info("Monitor: Using primary connected monitor (not dev monitor): #{@display_name}.")
    elsif connected_monitors.size > 1
      @display_name = connected_monitors[1] # Use the second monitor
      Environ.log_info("Monitor: Primary is dev monitor; using second connected monitor: #{@display_name}.")
    else
      @display_name = connected_monitors.first # Only one monitor, and it's the dev monitor
      Environ.log_warn("Monitor: Only one connected monitor found, and it's the dev monitor. Using: #{@display_name}.")
    end

    # Final check to ensure a display name was set
    if @display_name.nil? || @display_name.empty?
      @display_name = Environ.my_monitor_default
      Environ.log_error("Monitor: Could not determine a suitable display name. Falling back to hardcoded default: #{@display_name}.")
    end

    Environ.log_info("Monitor: Final selected display name: #{@display_name}.")
  end # set_display_name_with_fallback

  # ------------------------------------------------------------
  # verify_configuration -- Checks for critical monitor setup issues.
  # Raises MonitorError if configuration is incorrect.
  # ------------------------------------------------------------
  def verify_configuration
    Environ.log_info("Monitor: Verifying configuration.")
    begin
      set_display_name_with_fallback # This is where the name is set, and errors are handled here

      if @display_name.nil? || @display_name.empty?
        # This case should ideally be caught by set_display_name_with_fallback's fallback,
        # but as a final safeguard.
        raise MonitorError.new("Monitor display name could not be determined even with fallback.")
      end
      Environ.log_info("Monitor: Configuration verified successfully for display: #{@display_name}.")
    rescue MonitorError => e # Catch specific monitor configuration errors
      Environ.log_fatal("Monitor: Configuration error: #{e.message}")
      raise # Re-raise for AngaliaWork to handle as a MajorError
    rescue => e # Catch any other unexpected errors during configuration
      Environ.log_fatal("Monitor: Unexpected error during configuration verification: #{e.message}")
      raise MonitorError.new("Unexpected error during configuration verification: #{e.message}") # Wrap unexpected errors
    end
  end # verify_configuration

# ------------------------------------------------------------
# get_my_monitor -- Discovers all connected monitor display names via xrandr.
# Returns:
#   Array<String>: An array of connected monitor names (e.g., ["HDMI-A-0", "DP-1"]).
# Raises:
#   MonitorError: If xrandr command fails or finds no connected monitors.
# ------------------------------------------------------------
  def get_my_monitor()
    Environ.log_info("Monitor: Attempting to discover all connected monitor display names via xrandr.")
    begin
      # Use backticks to execute the command and capture its output
      # This will return multiple lines if multiple monitors are connected
      output = `xrandr | grep " connected" | cut -d " " -f1`.strip

      if output.empty?
        Environ.log_warn("Monitor: xrandr found no connected monitors.")
        raise MonitorError.new("No connected monitors found via xrandr.")
      else
        # Split the output by newline to get an array of monitor names
        monitor_names = output.split("\n").map(&:strip).reject(&:empty?)
        Environ.log_info("Monitor: Discovered connected display names: #{monitor_names.join(', ')}")
        return monitor_names
      end

    rescue => e # Catch any error from system command execution
      Environ.log_error("Monitor: Error executing xrandr command: #{e.message}")
      raise MonitorError.new("Error executing xrandr command for monitor discovery: #{e.message}") # Wrap and re-raise
    end

  end # get_my_monitor


  def turn_on
    Environ.log_info("Monitor: Turning on display.")
    begin
      success = system("xrandr --output #{@display_name} --auto")

      unless success
        raise MonitorOperationError.new("Failed to turn on monitor.")
      end
      @is_on = true
      Environ.log_info("Monitor: Display turned on.")
    rescue MonitorOperationError => e
      Environ.log_error("Monitor: Operation error turning on display: #{e.message}")
      @is_on = false # Ensure state is consistent with failure
      raise # Re-raise the specific error
    rescue => e
      Environ.log_error("Monitor: Unexpected error during display turn on: #{e.message}")
      @is_on = false
      raise MonitorOperationError.new("Unexpected error during display turn on: #{e.message}") # Wrap unexpected errors
    end
  end # turn_on

  def turn_off
    Environ.log_info("Monitor: Turning off display (unless debugging).")
    begin
      if Environ::DEBUG_MODE && Environ::IS_DEVELOPMENT
        success = true   # skip turning off monitor while debugging
      else   # production mode, always turn off
        success = system("xrandr --output #{@display_name} --off")
        @is_on = false
      end  # if debugging

      unless success
        raise MonitorOperationError.new("Failed to turn off monitor.")
      end
    rescue MonitorOperationError => e
      Environ.log_error("Monitor: Operation error turning off display: #{e.message}")
      # No need to change @is_on here, as it's already set to false
      raise # Re-raise the specific error
    rescue => e
      Environ.log_error("Monitor: Unexpected error during display turn off: #{e.message}")
      raise MonitorOperationError.new("Unexpected error during display turn off: #{e.message}") # Wrap unexpected errors
    end
  end # turn_off

  def on?
    @is_on
  end
  
  #  ------------------------------------------------------------
  #  ------------------------------------------------------------

end  # Class Monitor

end  # module Angalia
