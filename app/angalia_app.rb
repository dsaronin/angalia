#!/usr/bin/env ruby
# Angalia: A Remote Elder Monitoring System Client
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#
# angalia_app.rb  -- starting point for sinatra web app
#

require 'sinatra'
require 'sinatra/form_helpers' # Useful for potential forms on the home or status page
require 'rack-flash' # For displaying success/error messages to the user
require 'yaml' # Keep this, as it might be used by Environ or other configuration loading

# Assume AngaliaWork and Environ are loaded via config.ru and available globally
# through the ANGALIA constant.

class AngaliaApp < Sinatra::Application

  enable :sessions
  use Rack::Flash

  set :root, File.dirname(__FILE__)
  set :views, File.join(File.dirname(__FILE__), 'views') # Explicitly set views directory

  # ------------------------------------------------------------
  # Web Server Routes
  # ------------------------------------------------------------

  # 1. Home Page
  # GET /
  # Displays the main caregiver control panel with action buttons.
  get '/' do
    haml :index
  end # get /

  # 2. View Webcam Stream
  # GET /webcam_stream
  # Serves a continuous MJPEG stream from the Angalia webcam.
  get '/webcam_stream' do
    # Set the Content-Type header for MJPEG streaming.
    content_type 'multipart/x-mixed-replace; boundary=--BoundaryString'

    # Use Sinatra's streaming capabilities to send continuous data.
    stream do |out|
      begin
        # Ensure the webcam stream is active and writing to the named pipe.
        # ANGALIA.start_webcam_stream should be called here or ensured to be running
        # by the AngaliaWork setup.
        # The AngaliaWork instance (via its Webcam singleton) is responsible
        # for providing the named pipe path and reading frames from it.

        # Open the named pipe for reading.
        # ANGALIA.webcam_stream_pipe_path is assumed to provide the path to /tmp/CAMOUT.
        File.open(ANGALIA.webcam_stream_pipe_path, 'rb') do |pipe|
          # Continuously read and send frames.
          # This loop needs to identify JPEG frame boundaries within the pipe's output.
          # A more robust implementation would parse for 0xFFD8 (start) and 0xFFD9 (end) markers.
          # For this initial implementation, we'll assume ANGALIA.get_webcam_frame
          # handles reading a complete frame from the pipe.
          while true
            frame_data = ANGALIA.get_webcam_frame # Method to be implemented in AngaliaWork/Webcam

            if frame_data
              out << "--BoundaryString\r\n"
              out << "Content-Type: image/jpeg\r\n"
              out << "Content-Length: #{frame_data.length}\r\n"
              out << "\r\n"
              out << frame_data
              out << "\r\n"
            else
              # If no frame is available, wait briefly to prevent busy-waiting.
              sleep 0.1
            end
          end # while
        end # File.open
      rescue IOError, Errno::EPIPE => e
        # =============
        # Handle client disconnection or pipe errors gracefully.
        Environ.log_warn "Webcam stream client disconnected or pipe error: #{e.message}"
        # =============
      rescue => e
        # =============
        # Catch any other unexpected errors during streaming.
        Environ.log_error "Error streaming webcam: #{e.message}"
        # =============
      end # begin
    end # stream
  end # get /webcam_stream

  # 3. Start Jitsi Meet Session
  # POST /start_meet
  # Triggers the Angalia system to initiate a Jitsi Meet session.
  post '/start_meet' do
    begin
      if ANGALIA.start_meet
        flash[:success] = "Jitsi Meet session initiated successfully."
      else
        flash[:error] = "Failed to initiate Jitsi Meet session."
      end
    rescue Angalia::ConfigurationError => e
      # =============
      # Handle configuration-related errors.
      flash[:error] = "Configuration error preventing Jitsi Meet: #{e.message}"
      Environ.log_error "Configuration error during start_meet: #{e.message}"
      # =============
    rescue Angalia::OperationError => e
      # =============
      # Handle operational errors during the process.
      flash[:error] = "Operation error during Jitsi Meet initiation: #{e.message}"
      Environ.log_error "Operation error during start_meet: #{e.message}"
      # =============
    rescue => e
      # =============
      # Catch any other unexpected errors.
      flash[:error] = "An unexpected error occurred while starting Jitsi Meet: #{e.message}"
      Environ.log_error "Unexpected error during start_meet: #{e.message}"
      # =============
    end # begin
    redirect '/' # Redirect to the home page after action
  end # post /start_meet

  # 4. End Jitsi Meet Session
  # POST /end_meet
  # Triggers the Angalia system to terminate the active Jitsi Meet session.
  post '/end_meet' do
    begin
      if ANGALIA.end_meet
        flash[:success] = "Jitsi Meet session terminated successfully."
      else
        flash[:error] = "Failed to terminate Jitsi Meet session."
      end
    rescue Angalia::ConfigurationError => e
      # =============
      # Handle configuration-related errors.
      flash[:error] = "Configuration error preventing Jitsi Meet termination: #{e.message}"
      Environ.log_error "Configuration error during end_meet: #{e.message}"
      # =============
    rescue Angalia::OperationError => e
      # =============
      # Handle operational errors during the process.
      flash[:error] = "Operation error during Jitsi Meet termination: #{e.message}"
      Environ.log_error "Operation error during end_meet: #{e.message}"
      # =============
    rescue => e
      # =============
      # Catch any other unexpected errors.
      flash[:error] = "An unexpected error occurred while ending Jitsi Meet: #{e.message}"
      Environ.log_error "Unexpected error during end_meet: #{e.message}"
      # =============
    end # begin
    redirect '/' # Redirect to the home page after action
  end # post /end_meet

  # 5. View System Status (Developer/Debug)
  # GET /status
  # Displays current system status information for debugging/monitoring.
  get '/status' do
    # ANGALIA.do_status should return a hash or object with relevant data.
    @status_info = ANGALIA.do_status # Method to be implemented in AngaliaWork
    haml :status
  end # get /status

  # ------------------------------------------------------------
  # Error Handling
  # ------------------------------------------------------------

  # Generic error handler for 404 Not Found pages.
  not_found do
    status 404
    haml :not_found
  end

  # Generic error handler for 500 Internal Server Errors.
  error do
    status 500
    @error_message = env['sinatra.error'].message
    Environ.log_error "Internal Server Error: #{@error_message}"
    haml :error
  end

end # class AngaliaApp

