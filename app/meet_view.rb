# --- meet_view.rb ---
# Angalia: A Remote Elder Monitoring Hub
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#
# MeetView -- controls access to browser/meet sessions
# -----------------------------------------------------
require 'singleton'
require_relative 'environ' # Required for Environ.log_info
require_relative 'angalia_error' # Required for AngaliaError::MeetViewError
require 'timeout' # Required for Timeout.timeout in stop_session

# +++++++++++++++++++++++++++++++++++++++++++++++++
module Angalia              # Define the top-level module  
# +++++++++++++++++++++++++++++++++++++++++++++++++

class MeetView
  include Singleton

  def initialize
    @is_active = false
    verify_configuration # Perform configuration check on initialization
  end

  # verify_configuration -- Checks for flatpak and org.chromium.Chromium Flatpak installation.
  # Raises AngaliaError::MeetViewError if flatpak or the Chromium Flatpak is not found.
  # ------------------------------------------------------------
  def verify_configuration
    Environ.log_info("MeetView: Verifying configuration (Flatpak Chromium).")
    begin
      # Check if flatpak executable exists in PATH
      flatpak_path = `which flatpak`.strip
      if flatpak_path.empty?
        raise AngaliaError::MeetViewError.new("flatpak executable not found in PATH. Flatpak Chromium cannot be launched.")
      end
      Environ.log_info("MeetView: flatpak found at: #{flatpak_path}.")

      # Check if org.chromium.Chromium Flatpak is installed
      # `flatpak info org.chromium.Chromium` will return non-zero exit status if not installed
      # We redirect output to /dev/null to keep console clean.
      flatpak_chromium_installed = system("flatpak info org.chromium.Chromium > /dev/null 2>&1")
      unless flatpak_chromium_installed
        raise AngaliaError::MeetViewError.new("org.chromium.Chromium Flatpak not installed. Please install it.")
      end
      Environ.log_info("MeetView: org.chromium.Chromium Flatpak installation verified.")
      Environ.log_info("MeetView: Configuration verified successfully.")
    rescue AngaliaError::MeetViewError => e
      Environ.log_fatal("MeetView: Configuration error: #{e.message}")
      raise # Re-raise for AngaliaWork to handle as a MajorError
    rescue => e
      Environ.log_fatal("MeetView: Unexpected error during configuration verification: #{e.message}")
      raise AngaliaError::MeetViewError.new("Unexpected error during configuration verification: #{e.message}") # Wrap unexpected errors
    end
  end # verify_configuration

  # ------------------------------------------------------------
  # start_session -- Launches Flatpak Chromium in kiosk mode for Jitsi Meet.
  # If Environ::DEBUG_MODE is true, it does not use --kiosk.
  # Uses a dedicated user data directory to avoid profile selection.
  # Returns:
  #   true:  if session started successfully
  #   false: if session failed to start
  # Raises:
  #   AngaliaError::MeetViewError: If Chromium fails to launch.
  # ------------------------------------------------------------
  def start_session(jitsi_room_url)
    Environ.log_info("MeetView: Starting Jitsi session at #{jitsi_room_url}")
    begin
      # Command to launch Flatpak Chromium in kiosk mode with auto-join flags
      # `pgroup: true` makes it a process group leader, easier to kill all its children.
      # `[:out, :err]=>:devnull` redirects stdout/stderr to /dev/null to prevent console spam.
      # command = "flatpak run org.chromium.Chromium --kiosk --autoplay-policy=no-user-gesture-required " \
      #          "--use-fake-ui-for-media-stream --disable-gpu #{jitsi_room_url}"
      # Base command for Flatpak Chromium
      command_parts = ["flatpak", "run", "org.chromium.Chromium"]

      # Add --kiosk only if not in DEBUG_MODE
      command_parts << "--kiosk" unless Environ::DEBUG_MODE

      # Add other necessary flags
      command_parts << "--autoplay-policy=no-user-gesture-required"
      # command_parts << "--use-fake-ui-for-media-stream"
      command_parts << "--disable-gpu"
      # command_parts << "--disable-session-crashed-bubble" # Added to suppress restore prompt
      command_parts << "--no-first-run" # Suppress first-run wizard
      command_parts << "--user-data-dir=#{Environ::CHROMIUM_USER_DATA_DIR}" # Use dedicated profile
      # command_parts << jitsi_room_url
      command_parts << "--app=#{jitsi_room_url}" # Use --app flag to launch as an application      

      # Join parts into a single command string
      command = command_parts.join(" ")

      # Use Process.spawn to get PID and run in background
      @chromium_pid = Process.spawn(command, pgroup: true, [:out, :err] => '/dev/null')

      # Check if the process actually started
      sleep 0.1 # Give Chromium a moment to start

      unless Process.kill(0, @chromium_pid) # Check if process is still alive (signal 0 does not kill)
        raise AngaliaError::MeetViewError.new("Flatpak Chromium process failed to launch for Jitsi session.")
      end

      @is_active = true
      Environ.log_info("MeetView: Jitsi session started. Chromium PID: #{@chromium_pid}")
      return true
  
    rescue AngaliaError::MeetViewError => e
      Environ.log_error("MeetView: Error starting session: #{e.message}")
      @is_active = false
      @chromium_pid = nil
      raise # Re-raise the specific error
    rescue => e
      Environ.log_error("MeetView: Unexpected error during session start: #{e.message}")
      @is_active = false
      @chromium_pid = nil
      raise AngaliaError::MeetViewError.new("Unexpected error during session start: #{e.message}") # Wrap unexpected errors
    end
  
  end # start_session

  # ------------------------------------------------------------
  # stop_session -- Terminates the Flatpak Chromium process for Jitsi Meet.
  # Returns:
  #   true:  if session stopped successfully
  #   false: if session failed to stop
  # Raises:
  #   AngaliaError::MeetViewError: If Chromium process cannot be killed.
  # ------------------------------------------------------------
  def stop_session
    Environ.log_info("MeetView: Stopping Jitsi session.")
    return true unless @chromium_pid # Already stopped or never started

    begin
      # Send TERM signal to the process group to kill Chromium and its children
      # Using -pid sends signal to process group.
      Process.kill("TERM", -@chromium_pid) # Note the negative PID for process group

      # Wait for the process to terminate with a timeout
      Timeout.timeout(5) do # Give it 5 seconds to die gracefully
        Process.waitpid(@chromium_pid)
      end

      @is_active = false
      @chromium_pid = nil
      Environ.log_info("MeetView: Jitsi session stopped. Chromium PID #{@chromium_pid} terminated.")
      return true
  
    rescue Errno::ESRCH # No such process (already dead)
      Environ.log_warn("MeetView: Chromium process (PID: #{@chromium_pid}) not found, likely already terminated.")
      @is_active = false
      @chromium_pid = nil
      return true # Consider it successful if process is gone
    rescue Timeout::Error
      Environ.log_error("MeetView: Chromium process (PID: #{@chromium_pid}) did not terminate within 5 seconds. Attempting KILL.")
      begin
        Process.kill("KILL", -@chromium_pid) # Force kill
        Process.waitpid(@chromium_pid)
        Environ.log_info("MeetView: Chromium process (PID: #{@chromium_pid}) force-killed.")
        @is_active = false
        @chromium_pid = nil
        return true
      rescue Errno::ESRCH
        Environ.log_warn("MeetView: Chromium process (PID: #{@chromium_pid}) not found after KILL attempt, likely terminated.")
        @is_active = false
        @chromium_pid = nil
        return true
      rescue => e
        Environ.log_error("MeetView: Unexpected error during force-kill of Chromium (PID: #{@chromium_pid}): #{e.message}")
        raise AngaliaError::MeetViewError.new("Unexpected error during force-kill of Chromium: #{e.message}")
      end
    rescue => e
      Environ.log_error("MeetView: Unexpected error during session stop: #{e.message}")
      raise AngaliaError::MeetViewError.new("Unexpected error during session stop: #{e.message}") # Wrap unexpected errors
    end
  
  end # stop_session

  # ------------------------------------------------------------
  # active? -- Checks if the Jitsi Meet session is currently active.
  # Returns:
  #   boolean: true if active, false otherwise.
  # ------------------------------------------------------------
  def active?
    @is_active
  end

  # ------------------------------------------------------------
  # ------------------------------------------------------------
end # Class MeetView

end  # module Angalia

