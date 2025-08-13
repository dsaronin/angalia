#
# Angalia: A Remote Elder Monitoring Hub
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#

require 'singleton'
require 'open3'            # executing system commands and capturing output
require_relative 'environ' # Environ::MY_WEBCAM_NAME, Environ::WEBCAM_PIPE
require_relative 'angalia_error' # WebcamError, WebcamOperationError
require_relative 'mockframe'     # has the mock frame data (large)
require 'base64'
require 'timeout'                # Timeout module useful other operations.

# ------------------------------------------------------------
# --- webcam.rb ---
# ------------------------------------------------------------
# Singleton manages the webcam device, including configuration verification,
# and starting/stopping a low-bandwidth MJPEG stream to a named pipe.
# ------------------------------------------------------------
# ---- GENERAL NOTES ABOUT class Webcam  ---------------------
# ------------------------------------------------------------
# xxx_pipe Methods
# These methods (pipe_exists?, start_pipe_reading, stop_pipe_reading) 
# are solely focused on the management of the named pipe (/tmp/CAMOUT). 
# Their purpose is to ensure the pipe is created, opened for reading, and properly closed, 
# acting as the interface between the application and the file system pipe.

# xxxx_stream Methods
# These methods (initialize_stream, streaming?, start_stream, stop_stream, get_stream_frame) 
# are responsible for managing the ffmpeg process and the flow of actual image data. 
# They handle starting and stopping the ffmpeg command that generates the video stream 
# into the pipe, monitoring its status, and extracting individual JPEG frames 
# from the data flowing through the pipe.
# ------------------------------------------------------------

# +++++++++++++++++++++++++++++++++++++++++++++++++
module Angalia              # Define the top-level module  
# +++++++++++++++++++++++++++++++++++++++++++++++++

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

  # ***********************************************************************
  # ******** STATE INITIALIZATION & CONFIGURATION *************************
  # ***********************************************************************
  #
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

  # ***********************************************************************
  # ******** LIVESTREAM HANDLING ******************************************
  # ***********************************************************************
  #
  # ------------------------------------------------------------
  # start_livestream -- High-level method to begin live webcam streaming.
  # Ensures the named pipe is ready and starts the ffmpeg process.
  # This method is idempotent; does nothing if streaming already active.
  # Args:
  #   current_client_count (Integer): The number of active clients requesting the stream.
  # Raises AngaliaError::WebcamOperationError on failure.
  # ------------------------------------------------------------
  def start_livestream(current_client_count)
      return true if streaming?

    begin
      Environ.log_info("Webcam: Initiating livestream sequence...")

      start_pipe_reading # Ensures named pipe ready for reading/writing
      start_stream # Start ffmpeg process writing to the pipe

      Environ.log_info("Webcam: ...Livestream sequence initiated")
      return true
 
     # RESCUE BLOCK =======================================================
     rescue AngaliaError::WebcamOperationError => e
      Environ.log_error("Webcam: Failed Initiating livestream sequence: #{e.message}")
      clear_state # Ensure a clean state on failure
      raise # Re-raise for AngaliaWork to handle
    rescue => e
      msg = "Webcam: Unexpected error during livestream initiation: #{e.message}"
      Environ.log_error(msg)
      clear_state
      raise AngaliaError::WebcamOperationError.new(msg) # Wrap in our specific error
    end 
    # END RESCUE BLOCK ====================================================

   end # start_livestream

  # ------------------------------------------------------------
  # stop_livestream -- High-level method to terminate live webcam streaming.
  # Stops the ffmpeg process and closes the named pipe only if no clients remain.
  # Args:
  #   current_client_count (Integer): The number of active clients after this request.
  # Returns:
  #   true: If the termination sequence was attempted or not needed.
  # Raises:
  #    AngaliaError::WebcamOperationError on failure.
  # ------------------------------------------------------------
  def stop_livestream(current_client_count)
    # Only stop the actual stream if no clients are active.
    # && streaming is still active (don't try to stop an already stopped process)
    if current_client_count < 1 && streaming?
      Environ.log_info("Webcam: terminating livestream (#{current_client_count} clients)...")
      begin
        stop_stream        # Stop the ffmpeg process
        stop_pipe_reading  # Close the named pipe
        Environ.log_info("Webcam: ...Livestream sequence terminated.")

      # RESCUE BLOCK =======================================================
      rescue AngaliaError::WebcamOperationError => e
        Environ.log_error("Webcam: Failed terminating livestream sequence: #{e.message}")
        clear_state # Attempt to clean up state even if an error occurs
        raise # Re-raise for AngaliaWork to handle
      rescue => e
        msg = "Webcam: Unexpected error during livestream termination: #{e.message}"
        Environ.log_error(msg)
        clear_state
        raise AngaliaError::WebcamOperationError.new(msg) # Wrap in our specific error
      end
      # END RESCUE BLOCK ====================================================
    else
      Environ.log_info("Webcam: Stream remains active (client count: #{current_client_count}).")
    end  # fi .. client_count >= 1
    return true
  end # stop_livestream

  # ***********************************************************************
  # ******** STREAM HANDLING **********************************************
  # ***********************************************************************
 
  # ------------------------------------------------------------
  # streaming? -- Checks if the webcam is currently streaming.
  # Returns:
  #   boolean: true if streaming, false otherwise.
  # ------------------------------------------------------------
  def streaming?
    return !@ffmpeg_pid.nil?
  end

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
      FFMPEG_START_CMD = "ffmpeg -y -f v4l2 -i /dev/#{Environ::MY_WEBCAM_NAME} -s 640x480 -r 24 -an -f mjpeg #{Environ::WEBCAM_PIPE_PATH}"
      FFMPEG_ACTIVE_CHK  = "pgrep ffmpeg"
  # ------------------------------------------------------------
  # start_stream -- Initiates low-bandwidth MJPEG stream to named pipe.
  # runs ffmpeg in background, captures PID.
  # Raises AngaliaError::WebcamOperationError if stream fails to start.
  # ------------------------------------------------------------
  def start_stream
    return if streaming?  # if already started, nothing more to do
    begin
      Environ.log_info("Webcam: Starting low-bandwidth stream.")

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
  # TODO:   system( KILL_FIFO )   # removes any lingering PIPE?
  # Raises AngaliaError::WebcamOperationError if termination fails.
  # ------------------------------------------------------------
  def stop_stream
    unless @ffmpeg_pid
      Environ.log_info("Webcam: No ffmpeg process to stop.")
      return  # simple return if no ffmpeg process
    end

    begin
      Environ.log_info("Webcam: gracefully terminate ffmpeg process (PID: #{@ffmpeg_pid})...")
      
      # Attempt graceful termination (SIGTERM)
      Process.kill('TERM', @ffmpeg_pid)

      # Wait for the process to exit, with a timeout
      # @ffmpeg_wait_thr.join returns the thread itself if it exits, or nil on timeout
      unless @ffmpeg_wait_thr.join(5) # Wait up to 5 seconds for graceful exit
        Environ.log_warn("Webcam: ffmpeg process (PID: #{@ffmpeg_pid}) did not exit gracefully, forcing kill.")
        # If it didn't exit, force kill (SIGKILL)
        Process.kill('KILL', @ffmpeg_pid)
        # Wait again for forceful termination
        @ffmpeg_wait_thr.join(2) # Wait up to 2 more seconds for forceful exit
      end

      # Check if the process is still alive after attempts
      if @ffmpeg_wait_thr.alive?
        system( FFMPEG_KILL_ALL )   # forcefully terminate all ffmpeg processes
        msg = "Webcam: brute force termination of all ffmpeg processes"
        Environ.log_error(msg)
        raise AngaliaError::WebcamOperationError.new(msg)
      end

      Environ.log_info("Webcam: ffmpeg process (PID: #{@ffmpeg_pid}) terminated.")

      # RESCUE BLOCK =======================================================
    rescue Errno::ESRCH => e
      # Process not found, likely already dead. Log as info.
      Environ.log_info("Webcam: ffmpeg process (PID: #{@ffmpeg_pid}) not found or already terminated: #{e.message}")
    rescue AngaliaError::WebcamOperationError => e
      # Re-raise if our internal check determined a failure
      Environ.log_error("Webcam: Stream termination error: #{e.message}")
      raise
    rescue => e
      msg = "Webcam: Unexpected error during stream termination: #{e.message}"
      Environ.log_error(msg)
      raise AngaliaError::WebcamOperationError.new(msg)

    ensure
      # Always clear state regardless of success or failure
      clear_state
      Environ.log_info("Webcam: Stream stopped.") # This specific log message was preserved from original.
    end
      # END RESCUE BLOCK ====================================================
  
  end # stop_stream

  # ***********************************************************************
  # ******** GET STREAM FRAME (data input) ********************************
  # ***********************************************************************
  #
  # ------------------------------------------------------------
  # get_mock_webcam_frame  -- returns a static mocked up frame
  # ------------------------------------------------------------
  def get_mock_webcam_frame
    # Decode the base64 string into binary data.
    # Ensure the encoding is ASCII-8BIT (binary) which is appropriate for image data.
    Base64.decode64(MOCK_JPEG_FRAME_BASE64).force_encoding('ASCII-8BIT')
  end

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
  #   WebcamOperationError: If the pipe closes unexpectedly or a critical read/parse error occurs.
  # 
  # Note: 
  #   If JPEG_START is consistently missing or malformed,
  #   @buffer could grow indefinitely. A max buffer size might be considered.
  # ------------------------------------------------------------
    JPEG_START = "\xFF\xD8".force_encoding('ASCII-8BIT')
    JPEG_END   = "\xFF\xD9".force_encoding('ASCII-8BIT')
  # ------------------------------------------------------------
  def get_stream_frame(timeout_seconds = Environ::WEBCAM_READ_TIMEOUT_SECONDS)
    # return get_mock_webcam_frame  <-- CLI debugging usage only

    # Ensure the pipe is open before attempting to read
    unless @pipe_io && !@pipe_io.closed?
      # Log an error but don't raise here, as AngaliaWork expects nil if not ready.
      Environ.log_error "Webcam stream pipe is not open."
      return nil
    end

    begin
      # Use IO.select to wait for data on the pipe with a timeout.
      # This prevents blocking if no data is immediately available.
      readable_io, _, _ = IO.select([@pipe_io], nil, nil, timeout_seconds)

      if readable_io && readable_io.include?(@pipe_io)
        # Data is available, read a chunk non-blocking.
        # Adjust chunk size based on expected frame size/network conditions.
        chunk = @pipe_io.read_nonblock(4096) # Read up to 4KB non-blocking

        if chunk.nil? # EOF; ffmpeg process has stopped writing to the pipe
          raise AngaliaError::WebcamOperationError.new("Webcam stream pipe closed unexpectedly.")
        end

        @buffer << chunk
        # Environ.log_debug "Read #{chunk.length} bytes. Buffer size: #{@buffer.length}"
      else
        # No data available within the timeout.
        # Environ.log_debug "No new data on pipe within #{timeout_seconds} seconds."
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

          # Environ.log_debug "Extracted frame of size: #{frame.length} bytes."
          return frame
        end   # if end_index
      end   # if start_index

      # If we reach here, either no start marker yet, or start marker found but no end marker.
      nil  # Return nil: waiting for more data to form a complete frame

      # RESCUE BLOCK =======================================================
    rescue IO::WaitReadable # No data immediately available (read_nonblock)
      # This can happen if IO.select indicates readability but the data is consumed
      # before read_nonblock gets to it, or if there's a transient state.
      nil   # Return nil as no frame is ready yet.

    rescue EOFError # Pipe writer closed the pipe during read_nonblock
      raise AngaliaError::WebcamOperationError.new("Webcam stream pipe writer disconnected during read.")

    rescue => e
      # Catch any other unexpected errors during read or parsing.
      raise AngaliaError::WebcamOperationError.new("Error reading or parsing webcam stream: #{e.message}")
    end  # rescue
      # END RESCUE BLOCK ====================================================

  end # get_stream_frame

  # ***********************************************************************
  # ******** PIPE HANDLING ************************************************
  # ***********************************************************************
  
  # ------------------------------------------------------------
  # get_pipe_path  -- returns fully formed path
  # ------------------------------------------------------------
  def get_pipe_path
    return Environ::WEBCAM_PIPE_PATH
  end

  # ------------------------------------------------------------
  # pipe_exists?  -- returns true if streaming pipe exists
  # ------------------------------------------------------------
  def pipe_exists?
    return File.exist?(get_pipe_path)
  end

  # ------------------------------------------------------------
  # start_pipe_reading  -- initializes, manages named pipe
  # called when webcam streaming is started
  # args:
  #   pipe_path (defaults to call to get_pipe_path)
  # returns:
  #   pipe IO object
  # raises:
  #   WebcamOperationError
  # ------------------------------------------------------------
  def start_pipe_reading(pipe_path = get_pipe_path)
    # simply return if pipe already open
    if @pipe_io && !@pipe_io.closed?
      Environ.log_info "Webcam: Stream pipe already open."
      return @pipe_io # Return the existing pipe IO object
    end

    begin
      # Create named pipe if it doesn't exist
      unless File.exist?(pipe_path)
        Environ.log_info "Webcam: Creating named pipe at #{pipe_path}"
        # Ensure correct permissions: rw for owner, r for group/others
        stdout, stderr, status = Open3.capture3("mkfifo #{pipe_path}")
        unless status.success?
          msg = "Webcam: Failed to create named pipe at #{pipe_path}: #{stderr}"
          Environ.log_error(msg)
          raise AngaliaError::WebcamOperationError.new(msg)
        end  # failure
      end  # existed

      # Open the named pipe for reading
      @pipe_io = File.open(pipe_path, 'rb')
      @pipe_io.sync = true # Ensure reads are immediate
      Environ.log_info "Webcam: Stream pipe #{pipe_path} opened for reading."
      return @pipe_io # Return new pipe IO object

      # RESCUE BLOCK =======================================================
    rescue Errno::ENOENT => e
      msg = "Webcam: Named pipe file not found at #{pipe_path}. Error: #{e.message}"
      Environ.log_fatal(msg)
      raise AngaliaError::WebcamOperationError.new(msg) # Use WebcamOperationError
    rescue Errno::EACCES => e
      msg = "Webcam: Permission denied to access named pipe at #{pipe_path}. Error: #{e.message}"
      Environ.log_fatal(msg)
      raise AngaliaError::WebcamOperationError.new(msg) # Use WebcamOperationError
    rescue => e
      msg = "Webcam: Unexpected error while opening stream pipe: #{e.message}"
      Environ.log_fatal(msg)
      raise AngaliaError::WebcamOperationError.new(msg) # Use WebcamOperationError
    end  # end begin .. rescue block
      # END RESCUE BLOCK ====================================================

  end   # end start_pipe_reading

  # ------------------------------------------------------------
  # stop_pipe_reading  -- close named pipe
  # ------------------------------------------------------------
  def stop_pipe_reading
    if @pipe_io && !@pipe_io.closed?
      @pipe_io.close
      Environ.log_info "Webcam: stream pipe closed"
    end
    initialize_stream
  end

  # ***********************************************************************
  # ***********************************************************************
  
end # Class Webcam

end  # module Angalia

