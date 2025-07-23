#
# Angalia: A Remote Elder Monitoring Hub
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#

# --- webcam.rb ---
require 'singleton'
require_relative 'environ' # Required for Environ.log_info
require_relative 'angalia_error'

class Webcam
  include Singleton

  def initialize
    @is_streaming = false
    # Any other initial setup for the webcam
  end

  def start_stream
    Environ.log_info("Webcam: Starting low-bandwidth stream.")
    # Logic to start ffmpeg for the always-on stream
    # Ensure any previous ffmpeg process is killed first
    @is_streaming = true
    # TODO: system("ffmpeg -f v4l2 -i /dev/video0 -f mjpeg -an -update 1 - &")
  end

  def stop_stream
    Environ.log_info("Webcam: Stopping stream.")
    if Webcam.instance.streaming?
      # Logic to stop ffmpeg
      @is_streaming = false
      # TODO: system("pkill ffmpeg") or managing the process ID
    end  # if
  end

  def streaming?
    @is_streaming
  end
  
  #  ------------------------------------------------------------
  #  ------------------------------------------------------------

end  # Class Webcam
