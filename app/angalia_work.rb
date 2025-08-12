# --- angalia_work.rb ---
# Angalia: A Remote Elder Monitoring Hub
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#
# class AngaliaWork -- top-level control for doing everything
# accessed either from the CLI controller or the WEB i/f controller
#

  require_relative 'environ'
  require_relative 'webcam' # Required for Webcam Singleton
  require_relative 'monitor' # Required for Monitor Singleton
  require_relative 'meet_view' # Required for MeetView Singleton
  require_relative 'openvpn' # Required for OpenVPN Singleton
  require_relative 'angalia_error' # Required for AngaliaError classes

# +++++++++++++++++++++++++++++++++++++++++++++++++
module Angalia # Define the top-level module
# +++++++++++++++++++++++++++++++++++++++++++++++++

class AngaliaWork

  # ------------------------------------------------------------
  # initialize -- creates a new AngaliaWork object; inits environ
  # ------------------------------------------------------------
  def initialize()
    @my_env = Environ.instance # @my_env not used; placeholder
  end

  # ------------------------------------------------------------
  # setup_work -- handles initializing angalia system
  # This is the primary point for all critical device configurations.
  # ------------------------------------------------------------
  def setup_work()
    Environ.log_info("Starting ...")
    begin
      # Instantiate Singletons here. Their initialize methods will call verify_configuration.
      @my_monitor   = Monitor.instance
      @my_webcam    = Webcam.instance
      @my_meet_view = MeetView.instance
      @my_openvpn   = OpenVPN.instance # Instantiate OpenVPN Singleton

      # auto turn on vpn if in production
      unless Environ::IS_DEVELOPMENT
        @my_openvpn.start_vpn   # make sure vpn has started
      end

      Environ.log_info("AngaliaWork: All device configurations verified successfully.")
      # Environ.put_info FlashManager.show_defaults
    rescue AngaliaError::MajorError => e
      Environ.put_and_log_error("AngaliaWork: Critical startup error: #{e.message}")
      # Re-raise the error to the top-level CLI or web server
      # to prevent the application from running in a broken state.
      raise
    rescue => e
      Environ.put_and_log_error("AngaliaWork: An unexpected error occurred during setup: #{e.message}")
      raise # Re-raise any other unexpected errors
    end
  end # setup_work

  # ------------------------------------------------------------
  # shutdown_work -- handles pre-termination stuff
  # ------------------------------------------------------------
  def shutdown_work()
    Environ.log_info("...ending")
  end

  # ------------------------------------------------------------
  # do_status -- displays then returns status
  # ------------------------------------------------------------
  def do_status
    sts = Environ.to_sts
    Environ.put_info ">>>>> status: " + sts
    return sts
  end

  # ------------------------------------------------------------
  # do_flags -- displays then returns flag states
  # args:
  #   list -- cli array, with cmd at top
  # ------------------------------------------------------------
  def do_flags(list)
    list.shift # pop first element, the "f" command
    if (Environ.flags.parse_flags(list))
      Environ.change_log_level(Environ.flags.flag_log_level)
    end

    sts = Environ.flags.to_s
    Environ.put_info ">>>>> flags: " + sts
    return sts
  end

  # ------------------------------------------------------------
  # do_help -- displays then returns help line
  # ------------------------------------------------------------
  def do_help
    sts = Environ.angalia_help + "\n" + Environ.flags.to_help
    Environ.put_info sts
    return sts
  end

  # ------------------------------------------------------------
  # do_version -- displays then returns angalia version
  # ------------------------------------------------------------
  def do_version
    sts = Environ.app_name + " v" + Environ.angalia_version
    Environ.put_info sts
    return sts
  end

  # ------------------------------------------------------------
  # do_options -- display any options
  # ------------------------------------------------------------
  def do_options
    sts = ">>>>> options "
    Environ.put_info sts
    return sts
  end

  # ------------------------------------------------------------
  # start_meet -- Initiates a Jitsi Meet session
  #   true:  show success
  #   false: shows failure
  # ------------------------------------------------------------
  def start_meet
    Environ.log_info("Attempting Jitsi Meet session...")
    begin
      @my_openvpn.start_vpn   # make sure vpn has started
      @my_webcam.stop_stream  # Stop the webcam stream.
      @my_monitor.turn_on   # Turn on the monitor.

      # Start the Jitsi Meet session in Chromium
      @my_meet_view.start_session(Environ.jitsi_meet_room_url)

      Environ.log_info("Meet session initiation completed.")
      return true # Indicate success

    rescue AngaliaError::MajorError => e
      Environ.put_and_log_error(e.message) # Simplified message
      return false
    rescue AngaliaError::MinorError => e
      Environ.put_and_log_error(e.message) # Simplified message
      return false
    rescue => e
      Environ.put_and_log_error("An unexpected error occurred during start_meet: #{e.message}")
      return false
    end
  end   # start_meet

  # ------------------------------------------------------------
  # end_meet -- Terminates a Jitsi Meet session (placeholder for future)
  # Returns:
  #   true:  show success
  #   false: shows failure
  # ------------------------------------------------------------
  def end_meet
    Environ.log_info("Attempting to end Jitsi Meet session.")
    begin
      @my_meet_view.stop_session # Stop the Jitsi Meet session
      @my_monitor.turn_off     # Turn off the monitor
      @my_webcam.start_stream  # Restart the always-on webcam stream
      
         # disconnect the vpn when we're debugging system locally
      if Environ::DEBUG_MODE && Environ::DEBUG_VPN_OFF && Environ::IS_DEVELOPMENT
        @my_openvpn.disconnect_vpn_tunnel 
      end  # if debugging

      Environ.log_info("Jitsi Meet session termination sequence completed.")
      return true # Indicate success
    rescue AngaliaError::MinorError => e
      Environ.put_and_log_error(e.message) # Simplified message
      return false
    rescue => e
      Environ.put_and_log_error("An unexpected error occurred during end_meet: #{e.message}")
      return false
    end
  end # end_meet

  # ------------------------------------------------------------
  # webcam_on -- starts webcam streaming
  # ------------------------------------------------------------
  def webcam_on
    @my_webcam.start_stream
  end

  # ------------------------------------------------------------
  # webcam_off -- stops webcam streaming
  # ------------------------------------------------------------
  def webcam_off
    @my_webcam.stop_stream
  end

  # ------------------------------------------------------------
  # start_webcam_stream  -- starts webcam & returns streaming path
  # ------------------------------------------------------------
  def start_webcam_stream
    webcam_on
    return @my_webcam.get_pipe_path
  end

  # ------------------------------------------------------------
  # get_webcam_frame -- Extract and Return a Single Frame
  # ------------------------------------------------------------
  def get_webcam_frame
    return @my_webcam.get_stream_frame
  end  # get_webcam_frame

  # ------------------------------------------------------------
  # ------------------------------------------------------------

end # class AngaliaWork
end  # module Angalia

