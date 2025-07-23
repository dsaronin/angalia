# Angalia: A Remote Elder Monitoring Hub
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#
# class AngaliaWork -- top-level control for doing everything
# accessed either from the CLI controller or the WEB i/f controller
#

class AngaliaWork
  require_relative 'environ'
  require_relative 'angalia_error'
  require_relative 'webcam' # Required for Webcam Singleton
  require_relative 'monitor' # Required for Monitor Singleton
  require_relative 'meet_view' # Required for MeetView Singleton
 
  #  ------------------------------------------------------------
  #  initialize  -- creates a new object
  #  ------------------------------------------------------------
  def initialize()
    @my_env    = Environ.instance   # currently not used anywhere
    @my_monitor   = Monitor.instance  
    @my_webcam    = Webcam.instance  
    @my_meet_view = MeetView.instance  
  end

  #  ------------------------------------------------------------
  #  setup_work  -- handles initializing angalia system
  #  ------------------------------------------------------------
  def setup_work()
    Environ.log_info( "starting..." )
    # Environ.put_info FlashManager.show_defaults
  end

  #  ------------------------------------------------------------
  #  shutdown_work  -- handles pre-termination stuff
  #  ------------------------------------------------------------
  def shutdown_work()
    Environ.log_info( "...ending" )
  end
 
  #  ------------------------------------------------------------
  #  do_status  -- display list of all angalia rules
  #  ------------------------------------------------------------
  def do_status
    sts = ""
    Environ.put_info ">>>>> status:  " + sts
    return sts
  end

  #  ------------------------------------------------------------
  #  do_flags  -- display flag states
  #  args:
  #    list  -- cli array, with cmd at top
  #  ------------------------------------------------------------
  def do_flags(list)
    list.shift  # pop first element, the "f" command
    if ( Environ.flags.parse_flags( list ) )
      Environ.change_log_level( Environ.flags.flag_log_level )
    end

    sts = Environ.flags.to_s
    Environ.put_info ">>>>>  flags: " + sts
    return sts
  end

  #  ------------------------------------------------------------
  #  do_help  -- display help line
  #  ------------------------------------------------------------
  def do_help
    sts = Environ.angalia_help + "\n" + Environ.flags.to_help 
    Environ.put_info sts
    return sts
  end

  #  ------------------------------------------------------------
  #  do_version  -- display angalia version
  #  ------------------------------------------------------------
  def do_version        
    sts = Environ.app_name + " v" + Environ.angalia_version
    Environ.put_info sts  
    return sts
  end

  #  ------------------------------------------------------------
  #  do_options  -- display any options
  #  ------------------------------------------------------------
  def do_options        
    sts = ">>>>> options "
    Environ.put_info  sts  
    return sts
  end
 
  #  ------------------------------------------------------------
  #  ------ Angalia specific handling ---------------------------
  #  ------------------------------------------------------------

  # ------------------------------------------------------------
  # start_meet -- Initiates a Jitsi Meet session
  # ------------------------------------------------------------
  def start_meet
    Environ.log_info("Attempting to start Jitsi Meet session.")
    begin
      @my_webcam.stop_stream  # Stop the webcam stream.
      @my_monitor.turn_on   # Turn on the monitor.

      # Start the Jitsi Meet session in Chromium
      @my_meet_view.start_session(Environ.jitsi_meet_room_url)

      Environ.log_info("Jitsi Meet session initiation sequence completed.")
      return true # Indicate success

    rescue AngaliaError::MajorError => e # Catch specific major configuration/device errors
      Environ.put_and_log_error("Failed to start meet: #{e.message}")
      return false
    rescue AngaliaError::MinorError => e # Catch specific minor operational errors
      Environ.put_and_log_error("Issues when start meet: #{e.message}")
      return false
    rescue => e # Catch any other unexpected errors
      Environ.put_and_log_error("An unexpected error occurred during start_meet: #{e.message}")
      return false
    end

  end   # start_meet

  # ------------------------------------------------------------
  # end_meet -- Terminates a Jitsi Meet session (placeholder for future)
  # ------------------------------------------------------------
  def end_meet
    Environ.log_info("Attempting to end Jitsi Meet session (TODO: implement).")
    # TODO: Implement @my_meet_view.stop_session and @my_monitor.turn_off
    # TODO: Potentially restart @my_webcam.start_stream for always-on
    return true
  end

  # ------------------------------------------------------------
  # webcam -- Handles webcam specific commands (placeholder for future)
  # ------------------------------------------------------------
  def webcam
    Environ.log_info("Webcam command received (TODO: implement).")
    # TODO: Implement logic for webcam control, e.g., starting/stopping the always-on stream
    return true
  end

 
  #  ------------------------------------------------------------
  #  ------------------------------------------------------------

end  # class AngaliaWork

