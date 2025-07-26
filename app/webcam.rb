#
# Angalia: A Remote Elder Monitoring Hub
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#

# --- webcam.rb ---
# This class manages the webcam device, including configuration verification,
# and starting/stopping a low-bandwidth MJPEG stream to a named pipe.
require 'singleton'
require 'open3' # Required for executing system commands and capturing output
require_relative 'environ' # Required for Environ.log_info, Environ::MY_WEBCAM_NAME, Environ::WEBCAM_PIPE
require_relative 'angalia_error' # Required for AngaliaError::WebcamError, AngaliaError::WebcamOperationError
require 'base64'
require 'timeout' # Although IO.select handles the timeout, Timeout module useful other operations.

class Webcam
  include Singleton

  # ------------------------------------------------------------
  # new Webcam Singleton
  # ------------------------------------------------------------
  def initialize
    verify_configuration  # Perform configuration check on initialization
    clear_state
    initialize_stream
  end

  # ------------------------------------------------------------
    # @pipe_io is the File object for named streaming pipe
    # @buffer accumulates partial frame data
  # ------------------------------------------------------------
  def initialize_stream
    @pipe_io = nil
    @buffer = "" # Clear buffer on close
  end

  # ------------------------------------------------------------
  # clear_state  -- clears everything in the internal state
  # ------------------------------------------------------------
  def clear_state
    # current streaming state is true IFF @ffmpeg_pid is not nil
    @ffmpeg_pid = nil     # Stores the PID of the running ffmpeg process

    # @ffmpeg_stdin, @ffmpeg_stdout_stderr, @ffmpeg_wait_thr 
    # Used in for Open3.popen2e
    @ffmpeg_stdin&.close
    @ffmpeg_stdout_stderr&.close
    @ffmpeg_wait_thr&.value

    @ffmpeg_stdin = nil
    @ffmpeg_stdout_stderr = nil
    @ffmpeg_wait_thr = nil
  end # clear_state

  # ------------------------------------------------------------
  # verify_configuration -- Checks for critical webcam setup issues.
  # Ensures webcam device is present and accessible.
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
        msg = "Webcam: expected '/dev/#{Environ::MY_WEBCAM_NAME}' not found in v4l2-ctl output."
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
    end  # rescue block
      # END RESCUE BLOCK ====================================================

  end # verify_configuration

  # ------------------------------------------------------------
      # Construct ffmpeg command.
      # -y: Overwrite output without asking.
      # -f v4l2: Input format.
      # -i /dev/video0: Input device.
      # -s 640x480: Resolution.
      # -r 24: Frame rate.
      # -an: Disable audio.
      # -f mjpeg: Output format.
      # /tmp/CAMOUT: Output pipe.
  # ------------------------------------------------------------
      FFMPEG_START_CMD = "ffmpeg -y -f v4l2 -i /dev/#{Environ::MY_WEBCAM_NAME} -s 640x480 -r 24 -an -f mjpeg #{Environ::WEBCAM_PIPE}"
      FFMPEG_ACTIVE_CHK  = "pgrep ffmpeg"
  # ------------------------------------------------------------
  # start_stream -- Initiates low-bandwidth MJPEG stream to named pipe.
  # runs ffmpeg in background, captures PID.
  # Raises AngaliaError::WebcamOperationError if stream fails to start.
  # ------------------------------------------------------------
  def start_stream
    Environ.log_info("Webcam: Starting low-bandwidth stream.")
    begin
      stop_stream    # force existing ffmpegs to stop

      # Execute command and capture PID using Open3.popen2e for robust process management.
      @ffmpeg_stdin, @ffmpeg_stdout_stderr, @ffmpeg_wait_thr = Open3.popen2e(FFMPEG_START_CMD)
      @ffmpeg_pid = @ffmpeg_wait_thr.pid

      ffmpeg_pids = `pgrep ffmpeg`.strip
      # Check if process is running.
      if ffmpeg_pids&.empty?
        msg = "Webcam: Failed to start ffmpeg stream or retrieve PID."
        Environ.log_error(msg)
        raise AngaliaError::WebcamOperationError.new(msg)
      end

      @is_streaming = true # Update state
      Environ.log_info("Webcam: Stream started (PID: #{@ffmpeg_pid}).")

      # RESCUE BLOCK =======================================================
    rescue AngaliaError::WebcamOperationError => e
      Environ.log_error("Webcam: Stream start error: #{e.message}")
      clear_state
      raise # Re-raise for AngaliaWork to catch
    rescue => e
      msg = "Webcam: Unexpected stream start error: #{e.message}"
      Environ.log_error(msg)
      clear_state
      raise AngaliaError::WebcamOperationError.new(msg)
    end
      # END RESCUE BLOCK ====================================================
  end # start_stream

  # ------------------------------------------------------------
      FFMPEG_KILL_ALL  = "pkill -9 ffmpeg || true"
      KILL_FIFO  =  "rm /tmp/CAMOUT || true"
  # ------------------------------------------------------------
  # stop_stream -- Terminates the running webcam stream.
  # Forcefully kills all ffmpeg processes
  # ------------------------------------------------------------
  def stop_stream
      system( FFMPEG_KILL_ALL ) # kill any lingering ffmpeg procs
      # TODO?   system( KILL_FIFO )   # removes any lingering PIPE
      clear_state   
      Environ.log_info("Webcam: Stream stopped.")
  end # stop_stream

  # ------------------------------------------------------------
  # streaming? -- Checks if the webcam is currently streaming.
  # Returns:
  #   boolean: true if streaming, false otherwise.
  # ------------------------------------------------------------
  def streaming?
    return !@ffmpeg_pid.nil?
  end

  # ------------------------------------------------------------
  # get_pipe_path  -- returns fully formed path
  # ------------------------------------------------------------
  def get_pipe_path
    return Environ::WEBCAM_PIPE_PATH
  end

  # ------------------------------------------------------------
  # Mock data for a single, tiny JPEG frame (e.g., a 1x1 black pixel JPEG)
  # This is a base64 encoded string of a very small JPEG.
  # In a real scenario, this would come from the named pipe.
  # ------------------------------------------------------------
  MOCK_JPEG_FRAME_BASE64 = "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAD/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFAEBAAAAAAAAAAAAAAAAAAAAAP/EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAMAwEAAhEDEQA/AKgAD//Z"
  # ------------------------------------------------------------
  # This method would simulate reading a frame from the pipe.
  # For testing, it just decodes our mock data.
  # Example usage (for testing):
  # frame = webcam_instance.get_mock_webcam_frame
  # puts "Mock frame length: #{frame.length} bytes"
  # puts "Mock frame encoding: #{frame.encoding}"
  # ------------------------------------------------------------
  # get_mock_webcam_frame  -- returns a static mocked up frame
  # ------------------------------------------------------------
  def get_mock_webcam_frame
    # Decode the base64 string into binary data.
    # Ensure the encoding is ASCII-8BIT (binary) which is appropriate for image data.
    Base64.decode64(MOCK_JPEG_FRAME_BASE64).force_encoding('ASCII-8BIT')
  end

  # ------------------------------------------------------------
  # ------------------------------------------------------------
  # get_stream_frame  -- reads single JPEG frame from stream
  # Args:
  #   timeout_seconds (Float): The maximum time to wait for data (e.g., 0.1 or 0.2 seconds).
  #
  # Returns:
  #   String: The binary data of a complete JPEG frame if found within the timeout.
  #   nil: If no complete frame is found within the timeout, or if the pipe is not open/ready.
  #
  # Raises:
  #   Angalia::OperationError: If the pipe closes unexpectedly or a critical read/parse error occurs.
  # ------------------------------------------------------------
    JPEG_START = "\xFF\xD8".force_encoding('ASCII-8BIT')
    JPEG_END   = "\xFF\xD9".force_encoding('ASCII-8BIT')
  # ------------------------------------------------------------
  def get_stream_frame(timeout_seconds = Environ::WEBCAM_READ_TIMEOUT_SECONDS)
    return get_mock_webcam_frame 

    # Ensure the pipe is open before attempting to read
    unless @pipe_io && !@pipe_io.closed?
      # Log an error but don't raise here, as AngaliaWork expects nil if not ready.
      Environ.log_error "Webcam stream pipe is not open or has been closed."
      return nil
    end

    begin
      # Use IO.select to wait for data on the pipe with a timeout.
      readable_io, _, _ = IO.select([@pipe_io], nil, nil, timeout_seconds)

      if readable_io && readable_io.include?(@pipe_io)
        # Data is available, read a chunk non-blocking.
        # Adjust chunk size based on expected frame size/network conditions.
        chunk = @pipe_io.read_nonblock(4096) # Read up to 4KB non-blocking

        if chunk.nil? # EOF reached, pipe closed by writer
          raise Angalia::OperationError.new("Webcam stream pipe closed unexpectedly by writer.")
        end

        @buffer << chunk
        # Environ.log_debug "Read #{chunk.length} bytes. Buffer size: #{@buffer.length}" # For debugging
      else
        # No data available within the timeout.
        # Environ.log_debug "No new data on pipe within #{timeout_seconds} seconds." # Too verbose
        return nil
      end

      # Attempt to find a complete JPEG frame in the buffer.
      start_index = @buffer.index(JPEG_START)
      if start_index
        end_index = @buffer.index(JPEG_END, start_index + JPEG_START.length)
        if end_index
          # Found a complete frame
          frame_end_pos = end_index + JPEG_END.length
          frame = @buffer.byteslice(start_index, frame_end_pos - start_index)

          # Remove the extracted frame from the buffer for the next read
          @buffer = @buffer.byteslice(frame_end_pos, @buffer.length - frame_end_pos)

          # Environ.log_debug "Extracted frame of size: #{frame.length} bytes." # For debugging
          return frame
        end   # if end_index
      end   # if start_index

      # If we reach here, either no start marker yet, or start marker found but no end marker.
      # Return nil, indicating more data is needed to form a complete frame.
      nil

      # RESCUE BLOCK =======================================================
    rescue IO::WaitReadable # No data immediately available (read_nonblock)
      # This can happen if IO.select indicates readability but the data is consumed
      # before read_nonblock gets to it, or if there's a transient state.
      nil
    rescue EOFError # Pipe writer closed the pipe during read_nonblock
      raise Angalia::OperationError.new("Webcam stream pipe writer disconnected during read.")
    rescue => e
      # =============
      # Catch any other unexpected errors during read or parsing.
      raise Angalia::OperationError.new("Error reading or parsing webcam stream: #{e.message}")
      # =============
    end  # rescue
      # END RESCUE BLOCK ====================================================
  end # get_stream_frame

  # ------------------------------------------------------------
  # pipe_exists?  -- returns t if the streaming pipe exists
  # ------------------------------------------------------------
  def pipe_exists?
    return File.exist?(pipe_path)
  end

  # ------------------------------------------------------------
  # start_pipe_reading  -- initializes, manages named pipe
  # called when webcam streaming is started
  # ------------------------------------------------------------
  def start_pipe_reading(pipe_path = Environ::WEBCAM_PIPE_PATH)
    @pipe_io = File.open(pipe_path, 'rb')
    @pipe_io.sync = true # Ensure reads are immediate
    Environ.log_info "Webcam: #{pipe_path} opened for reading"
    
    rescue => e
      raise Angalia::ConfigurationError.new("Failed to open #{e.message}")
  end   # end start_pipe_reading

  # ------------------------------------------------------------
  # Method to close the named pipe.
  # ------------------------------------------------------------
  def stop_pipe_reading
    if @pipe_io && !@pipe_io.closed?
      @pipe_io.close
      Environ.log_info "Webcam: stream pipe closed."
    end
    initialize_stream
  end

  # ------------------------------------------------------------
  # ------------------------------------------------------------
  #
end # Class Webcam

