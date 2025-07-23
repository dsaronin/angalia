#
# Angalia: A Remote Elder Monitoring Hub
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#

# --- webcam.rb ---
require 'singleton'
require_relative 'environ' # Required for Environ.log_info
require_relative 'angalia_error' # Required for AngaliaError::WebcamError, AngaliaError::WebcamOperationError

class Webcam
  include Singleton

  def initialize
    @is_streaming = false
    verify_configuration # Perform configuration check on initialization
  end

  # ------------------------------------------------------------
  # verify_configuration -- Checks for critical webcam setup issues.
  # Raises AngaliaError::WebcamError if configuration is incorrect.
  # ------------------------------------------------------------
  def verify_configuration
    Environ.log_info("Webcam: Verifying configuration.")
    begin
      # TODO: Replace with actual system call to check webcam presence/accessibility
      # Example: Check if /dev/video0 exists and is accessible, or use v4l2-ctl
      # For now, simulate success:
      webcam_present = true # Simulate successful webcam detection

      unless webcam_present
        raise AngaliaError::WebcamError.new("Webcam device not found or not accessible.")
      end
      Environ.log_info("Webcam: Configuration verified successfully.")

    rescue AngaliaError::WebcamError => e
      Environ.log_fatal("Webcam: Configuration error: #{e.message}")
      raise # Re-raise for AngaliaWork to handle as a MajorError
    rescue => e
      Environ.log_fatal("Webcam: Unexpected error during configuration verification: #{e.message}")
      raise AngaliaError::WebcamError.new("Unexpected error during configuration verification: #{e.message}") # Wrap unexpected errors
    end

  end # verify_configuration

  def start_stream
    Environ.log_info("Webcam: Attempting to start low-bandwidth stream.")
    begin
      # TODO: Replace with actual system call for ffmpeg
      # Example: success = system("ffmpeg -f v4l2 -i /dev/video0 -f mjpeg -an -update 1 - &")
      # For now, simulate success:
      success = true # Simulate successful command execution

      unless success
        raise AngaliaError::WebcamOperationError.new("Failed to start ffmpeg stream.")
      end
      @is_streaming = true
      Environ.log_info("Webcam: Low-bandwidth stream started.")
    rescue AngaliaError::WebcamOperationError => e
      Environ.log_error("Webcam: Operation error starting stream: #{e.message}")
      @is_streaming = false # Ensure state is consistent with failure
      raise # Re-raise the specific error for AngaliaWork to catch
    rescue => e
      Environ.log_error("Webcam: Unexpected error during stream start: #{e.message}")
      @is_streaming = false
      raise AngaliaError::WebcamOperationError.new("Unexpected error during stream start: #{e.message}") # Wrap unexpected errors
    end
  end # start_stream

  def stop_stream
    Environ.log_info("Webcam: Attempting to stop stream.")
    begin
      # TODO: Replace with actual system call for pkill ffmpeg
      # Example: success = system("pkill ffmpeg")
      # For now, simulate success:
      success = true # Simulate successful command execution

      unless success
        raise AngaliaError::WebcamOperationError.new("Failed to stop ffmpeg process.")
      end
      @is_streaming = false
      Environ.log_info("Webcam: Stream stopped.")
    rescue AngaliaError::WebcamOperationError => e
      Environ.log_error("Webcam: Operation error stopping stream: #{e.message}")
      # No need to change @is_streaming here, as it's already set to false
      raise # Re-raise the specific error
    rescue => e
      Environ.log_error("Webcam: Unexpected error during stream stop: #{e.message}")
      raise AngaliaError::WebcamOperationError.new("Unexpected error during stream stop: #{e.message}") # Wrap unexpected errors
    end
  end # stop_stream

  def streaming?
    @is_streaming
  end
  
  # ------------------------------------------------------------
  # ------------------------------------------------------------

end # Class Webcam

