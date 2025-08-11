#!/usr/bin/env ruby
# Angalia: A Remote Elder Monitoring System Client
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#
# angalia_app.rb  -- starting point for sinatra web app
#

require 'sinatra'
require 'haml'
require_relative 'tag_helpers'
require 'sinatra/form_helpers' # Useful for potential forms on the home or status page
require 'rack-flash' # For displaying success/error messages to the user
require 'yaml' # Keep this, as it might be used by Environ or other configuration loading

# Assumes AngaliaWork and Environ are loaded via config.ru and available globally
# through the ANGALIA constant.

# +++++++++++++++++++++++++++++++++++++++++++++++++
module Angalia # Define the top-level module
# +++++++++++++++++++++++++++++++++++++++++++++++++


class AngaliaApp < Sinatra::Application
  helpers Sinatra::AssetHelpers # Explicitly include your AssetHelpers

  enable :sessions
  use Rack::Flash

  set :root, File.dirname(__FILE__)
  set :views, File.join(File.dirname(__FILE__), 'views') # Explicitly set views directory
  
 # Disable show_exceptions in development to ensure 'error do' block is hit
 # set :show_exceptions, false # used for testing

  # ------------------------------------------------------------
  # Web Server Routes
  # ------------------------------------------------------------

  # 1. Home Page
  # GET /
  # Displays the main caregiver control panel with action buttons.
  get '/' do
    haml :index
  end # get /

  get '/disclaimers' do
    haml :disclaimers
  end

  get '/about' do
    haml :about
  end


  # ------------------------------------------------------------
  # View Webcam Stream
  # GET /webcam_stream
  # Serves a continuous MJPEG stream from the Angalia webcam.
  # ------------------------------------------------------------
  # Uses Sinatra's streaming capabilities to send continuous data.
  # ------------------------------------------------------------
  # A more robust implementation would parse for 0xFFD8 (start) and 0xFFD9 (end) markers.
  # For this initial implementation, we'll assume ANGALIA.get_webcam_frame
  # handles reading a complete frame from the pipe.
  # ------------------------------------------------------------
  # ------------------------------------------------------------
  get '/webcam_stream' do


    # Set the Content-Type header for MJPEG streaming.
    content_type 'multipart/x-mixed-replace; boundary=--BoundaryString'

    stream do |out|
      # make sure streaming is active; returns streaming_pipe
      streaming_pipe_path = ANGALIA.start_webcam_stream

      begin  # Continuously read and send frames.
        File.open(streaming_pipe_path, 'rb') do |pipe|
        
          # identify JPEG frame boundaries within the pipe's output
          while true
            frame_data = ANGALIA.get_webcam_frame 

            if frame_data
              out << "--BoundaryString\r\n"
              out << "Content-Type: image/jpeg\r\n"
              out << "Content-Length: #{frame_data.length}\r\n"
              out << "\r\n"
              out << frame_data
              out << "\r\n"
            else
              # If no frame is available, wait briefly to prevent busy-waiting
              sleep 0.1
            end  # fi
          end # while
        end # File.open
      rescue IOError, Errno::EPIPE => e
        # =============
        # Handle client disconnection or pipe errors gracefully.
        Environ.log_warn "Webcam stream client disconnected / pipe error: #{e.message}"
        # =============
      rescue => e
        # =============
        # Catch any other unexpected errors during streaming.
        Environ.log_error "Error streaming webcam: #{e.message}"
        # =============
      end # begin ... rescue block
    end # stream do out block

  end # get /webcam_stream
  # ------------------------------------------------------------

  # ------------------------------------------------------------
  # Start Jitsi Meet Session
  # POST /start_meet
  # Triggers the Angalia system to initiate a Jitsi Meet session.
  # ------------------------------------------------------------
 post '/start_meet' do

   start_thread = Thread.new do
     begin
       if ANGALIA.start_meet
         Environ.log_info "HUB: Jitsi Meet session initiated as background task."
       else
         Environ.log_error "HUB: Jitsi Meet failed to initiate as background task.."
       end

     rescue ConfigurationError => e
       # =============
       # Handle configuration-related errors.
       Environ.log_error "HUB: start_meet configuration error (background task): #{e.message}"
       # =============
     rescue OperationError => e
       # =============
       # Handle operational errors during the process.
       Environ.log_error "HUB: Operation error, start_meet (background task): #{e.message}"
       # =============
     rescue => e
       # =============
       # Catch any other unexpected errors.
       Environ.log_error "HUB: unexpected error starting Jitsi Meet (background task): #{e.message}"
       # =============
     end # begin
   end # Thread.new

   # start_thread.join   # waits for completion

   # Immediately send a response indicating the action has been triggered.
   flash[:notice] = "Starting video meeting... connecting shortly."
   redirect '/' # Redirect to the home page immediately

 end # post /start_meet

 # ------------------------------------------------------------
 # End Jitsi Meet Session
 # POST /end_meet
 # Triggers the Angalia system to terminate the active Jitsi Meet session.
 # ------------------------------------------------------------
 post '/end_meet' do

   stop_thread = Thread.new do
     begin
       if ANGALIA.end_meet
         Environ.log_info "HUB: Video Meet terminated in background."
       else
         Environ.log_error "HUB: Video Meet failed to terminate in background."
       end
     rescue ConfigurationError => e
       # =============
       # Handle configuration-related errors.
       Environ.log_error "HUB: Configuration error during end_meet (background task): #{e.message}"
       # =============
     rescue OperationError => e
       # =============
       # Handle operational errors during the process.
       Environ.log_error "HUB: Operation error during end_meet (background task): #{e.message}"
       # =============
     rescue => e
       # =============
       # Catch any other unexpected errors.
       Environ.log_error "HUB: Unexpected error at end_meet (background task): #{e.message}"
       # =============
     end # begin
   end # Thread.new

   # stop_thread.join   # waits for completion

   # Immediately send a response indicating the action has been triggered.
   flash[:notice] = "Terminating video meeting... disconnecting shortly."
   redirect '/' # Redirect to the home page immediately

 end # post /end_meet


  # ------------------------------------------------------------
  # View System Status (Developer/Debug)
  # GET /status
  # Displays current system status information for debugging/monitoring.
  # ------------------------------------------------------------
  get '/status' do
    # ANGALIA.do_status should return a hash or object with relevant data.
    @status_info = ANGALIA.do_status 
    flash[:error] = @status_info
    redirect '/'
  end # get /status

  # ------------------------------------------------------------
  # Error Handling
  # ------------------------------------------------------------

  # ------------------------------------------------------------
  # Generic error handler for 404 Not Found pages.
  # ------------------------------------------------------------
  not_found do
    status 404
    haml :err_404
  end

  # ------------------------------------------------------------
  # Generic error handler for 500 Internal Server Errors.
  # ------------------------------------------------------------
  error do
    status 500
    @error_message = env['sinatra.error'].message
    Environ.log_error "Internal Server Error: #{@error_message}"
    haml :err_500
  end
  # ------------------------------------------------------------
    # TEMPORARY ROUTE TO FORCE 500 ERROR
  # ------------------------------------------------------------
    get '/force_500' do
      raise "This is a forced 500 error for testing purposes!"
    end
    # END TEMPORARY ROUTE
  # ------------------------------------------------------------


end # class AngaliaApp

end  # module Angalia
