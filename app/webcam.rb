#
# Angalia: A Remote Elder Monitoring Hub
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#

# --- webcam.rb ---
# This class manages the webcam device, including configuration verification,
# and starting/stopping a low-bandwidth MJPEG stream to a named pipe.
require 'singleton'
require 'open3' # Required for executing system commands and capturing output
require_relative 'environ' # Required for Environ.log_info, Environ::MY_WEBCAM_NAME
require_relative 'angalia_error' # Required for AngaliaError::WebcamError, AngaliaError::WebcamOperationError

class Webcam
  include Singleton

  def initialize
    verify_configuration  # Perform configuration check on initialization
    @is_streaming = false # current streaming state
  end

  # ------------------------------------------------------------
  # verify_configuration -- Checks for critical webcam setup issues.
  # This method ensures that the webcam device is present and accessible
  # before any streaming operations are attempted.
  # Raises AngaliaError::WebcamError if configuration is incorrect.
  # ------------------------------------------------------------
  def verify_configuration
    begin
      Environ.log_info("Webcam: Checking for webcam [v4l2-ctl].")
      stdout, stderr, status = Open3.capture3("v4l2-ctl --list-devices")

      unless status.success?
        msg = "Webcam: v4l2-ctl query failed: #{stderr}"
        Environ.log_error(msg)
        raise AngaliaError::WebcamError.new(msg)
      end

      unless stdout.include?(Environ::MY_WEBCAM_NAME)
        msg = "Webcam: expected '#{Environ::MY_WEBCAM_NAME}' not found in v4l2-ctl output."
        Environ.log_error(msg)
        raise AngaliaError::WebcamError.new(msg)
      end

      Environ.log_info("Webcam: Found '/dev/#{Environ::MY_WEBCAM_NAME}'.")

      # RESCUE BLOCK =======================================================
    rescue Errno::ENOENT => e
      msg = "Webcam: 'v4l2-ctl' command not found. Error: #{e.message}"
      Environ.log_fatal(msg)
      raise AngaliaError::WebcamError.new(msg)
    rescue AngaliaError::WebcamError => e
      # Catches specific configuration errors and re-raises them after logging
      Environ.log_fatal("Webcam: Configuration error: #{e.message}")
      raise # Re-raise for AngaliaWork to handle as a MajorError
    rescue => e
      # Catches any unexpected errors during configuration verification
      msg ="Webcam: Unexpected error verify_configuration: #{e.message}" 
      Environ.log_fatal(msg)
      raise AngaliaError::WebcamError.new(msg)
    end
      # END RESCUE BLOCK ====================================================

  end # verify_configuration

  # ------------------------------------------------------------
  # start_stream -- Initiates a low-bandwidth MJPEG stream from the webcam.
  # This method is intended to run an ffmpeg process that captures video
  # and outputs it to a named pipe (Environ::WEBCAM_PIPE).
  # Raises AngaliaError::WebcamOperationError if the stream fails to start.
  # ------------------------------------------------------------
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
      @is_streaming = true # Update streaming state on success
      Environ.log_info("Webcam: Low-bandwidth stream started.")
    rescue AngaliaError::WebcamOperationError => e
      # Handles specific operation errors during stream start
      Environ.log_error("Webcam: Operation error starting stream: #{e.message}")
      @is_streaming = false # Ensure state is consistent with failure
      raise # Re-raise the specific error for AngaliaWork to catch
    rescue => e
      # Handles any unexpected errors during stream start
      Environ.log_error("Webcam: Unexpected error during stream start: #{e.message}")
      @is_streaming = false
      raise AngaliaError::WebcamOperationError.new("Unexpected error during stream start: #{e.message}") # Wrap unexpected errors
    end
  end # start_stream

  # ------------------------------------------------------------
  # stop_stream -- Terminates the currently running webcam stream.
  # This method is intended to stop the ffmpeg process that is writing
  # to the named pipe.
  # Raises AngaliaError::WebcamOperationError if the stream fails to stop.
  # ------------------------------------------------------------
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
      @is_streaming = false # Update streaming state on success
      Environ.log_info("Webcam: Stream stopped.")
    rescue AngaliaError::WebcamOperationError => e
      # Handles specific operation errors during stream stop
      Environ.log_error("Webcam: Operation error stopping stream: #{e.message}")
      # No need to change @is_streaming here, as it's already set to false
      raise # Re-raise the specific error
    rescue => e
      Environ.log_error("Webcam: Unexpected error during stream stop: #{e.message}")
      raise AngaliaError::WebcamOperationError.new("Unexpected error during stream stop: #{e.message}") # Wrap unexpected errors
    end
  end # stop_stream

  # ------------------------------------------------------------
  # streaming? -- Checks if the webcam is currently streaming.
  # Returns:
  #   boolean: true if streaming, false otherwise.
  # ------------------------------------------------------------
  def streaming?
    @is_streaming
  end

  # ------------------------------------------------------------
  # ------------------------------------------------------------

end # Class Webcam

