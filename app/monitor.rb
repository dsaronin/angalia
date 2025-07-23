#
# Angalia: A Remote Elder Monitoring Hub
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#

# --- monitor.rb ---
require 'singleton'
require_relative 'environ' # Required for Environ.log_info, Environ.my_monitor_default
require_relative 'angalia_error' # Required for AngaliaError::MonitorError, AngaliaError::MonitorOperationError

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
    Environ.log_info("Monitor: Setting display name with fallback.")
    begin
      # Attempt dynamic discovery
      discovered_name = get_my_monitor()
      if discovered_name && !discovered_name.empty?
        @display_name = discovered_name
        Environ.log_info("Monitor: Display name set to: #{@display_name}.")
      else
        # Fallback to default if dynamic discovery returns empty or nil
        @display_name = Environ.my_monitor_default
        Environ.log_warn("Monitor: Dynamic discovery failed or returned empty. Using default: #{@display_name}.")
      end
    rescue AngaliaError::MonitorError => e # Catch specific error from get_my_monitor
      Environ.log_warn("Monitor: Dynamic discovery failed: #{e.message}. Using default: #{Environ.my_monitor_default}")
      @display_name = Environ.my_monitor_default # Fallback to default on error
    rescue => e # Catch any other unexpected errors during discovery
      Environ.log_warn("Monitor: Unexpected error during dynamic discovery: #{e.message}. Using default: #{Environ.my_monitor_default}")
      @display_name = Environ.my_monitor_default # Fallback to default on unexpected error
    end  # rescue block
  end # set_display_name_with_fallback

  # ------------------------------------------------------------
  # verify_configuration -- Checks for critical monitor setup issues.
  # Raises AngaliaError::MonitorError if configuration is incorrect.
  # ------------------------------------------------------------
  def verify_configuration
    Environ.log_info("Monitor: Verifying configuration.")
    begin
      set_display_name_with_fallback # This is where the name is set, and errors are handled here

      if @display_name.nil? || @display_name.empty?
        # This case should ideally be caught by set_display_name_with_fallback's fallback,
        # but as a final safeguard.
        raise AngaliaError::MonitorError.new("Monitor display name could not be determined even with fallback.")
      end
      Environ.log_info("Monitor: Configuration verified successfully for display: #{@display_name}.")
    rescue AngaliaError::MonitorError => e # Catch specific monitor configuration errors
      Environ.log_fatal("Monitor: Configuration error: #{e.message}")
      raise # Re-raise for AngaliaWork to handle as a MajorError
    rescue => e # Catch any other unexpected errors during configuration
      Environ.log_fatal("Monitor: Unexpected error during configuration verification: #{e.message}")
      raise AngaliaError::MonitorError.new("Unexpected error during configuration verification: #{e.message}") # Wrap unexpected errors
    end
  end # verify_configuration


  def get_my_monitor()
    Environ.log_info("Monitor: Attempting to discover monitor display name via xrandr.")
    begin
      # Use backticks to execute the command and capture its output
      output = `xrandr | grep " connected" | cut -d " " -f1`.strip
      if output.empty?
        Environ.log_warn("Monitor: xrandr found no connected monitor.")
        raise AngaliaError::MonitorError.new("No connected monitor found via xrandr.")
      else
        Environ.log_info("Monitor: Discovered display name: #{output}")
        return output
      end
    rescue => e # Catch any error from system command execution
      Environ.log_error("Monitor: Error executing xrandr command: #{e.message}")
      raise AngaliaError::MonitorError.new("Error executing xrandr command for monitor discovery: #{e.message}") # Wrap and re-raise
    end
  end # get_my_monitor

  def turn_on
    Environ.log_info("Monitor: Turning on display.")
    begin
      # TODO: success = system("xrandr --output #{@display_name} --auto") or system("xset dpms force on")
      success = true # Simulate successful command execution

      unless success
        raise AngaliaError::MonitorOperationError.new("Failed to turn on monitor.")
      end
      @is_on = true
      Environ.log_info("Monitor: Display turned on.")
    rescue AngaliaError::MonitorOperationError => e
      Environ.log_error("Monitor: Operation error turning on display: #{e.message}")
      @is_on = false # Ensure state is consistent with failure
      raise # Re-raise the specific error
    rescue => e
      Environ.log_error("Monitor: Unexpected error during display turn on: #{e.message}")
      @is_on = false
      raise AngaliaError::MonitorOperationError.new("Unexpected error during display turn on: #{e.message}") # Wrap unexpected errors
    end
  end # turn_on

  def turn_off
    Environ.log_info("Monitor: Turning off display.")
    begin
      # TODO: success = system("xrandr --output #{@display_name} --off") or system("xset dpms force off")
      success = true # Simulate successful command execution

      unless success
        raise AngaliaError::MonitorOperationError.new("Failed to turn off monitor.")
      end
      @is_on = false
      Environ.log_info("Monitor: Display turned off.")
    rescue AngaliaError::MonitorOperationError => e
      Environ.log_error("Monitor: Operation error turning off display: #{e.message}")
      # No need to change @is_on here, as it's already set to false
      raise # Re-raise the specific error
    rescue => e
      Environ.log_error("Monitor: Unexpected error during display turn off: #{e.message}")
      raise AngaliaError::MonitorOperationError.new("Unexpected error during display turn off: #{e.message}") # Wrap unexpected errors
    end
  end # turn_off

  def on?
    @is_on
  end
  
  #  ------------------------------------------------------------
  #  ------------------------------------------------------------

end  # Class Monitor

