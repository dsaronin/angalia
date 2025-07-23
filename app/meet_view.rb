#
# Angalia: A Remote Elder Monitoring Hub
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#

# --- meet_view.rb ---
require 'singleton'
require_relative 'environ' # Required for Environ.log_info
require_relative 'angalia_error'

class MeetView
  include Singleton

  def initialize
    @is_active = false
    @chromium_pid = nil # To store the PID of the Chromium process
  end

  def start_session(jitsi_room_url)
    Environ.log_info("MeetView: Starting Jitsi session at #{jitsi_room_url}")
    # Logic to launch Chromium in kiosk mode with auto-join flags
    # TODO: command = "chromium-browser --kiosk --autoplay-policy=no-user-gesture-required " \
    #           "--use-fake-ui-for-media-stream --disable-gpu #{jitsi_room_url} &"
    # TODO: @chromium_pid = Process.spawn(command, pgroup: true) # Use Process.spawn to get PID
    @is_active = true
  end

  def stop_session
    Environ.log_info("MeetView: Stopping Jitsi session.")
    # Logic to kill Chromium process using @chromium_pid
    # TODO: Process.kill("TERM", @chromium_pid) if @chromium_pid
    @is_active = false
    @chromium_pid = nil
  end

  def active?
    @is_active
  end
  
  #  ------------------------------------------------------------
  #  ------------------------------------------------------------

end  # Class MeetView

