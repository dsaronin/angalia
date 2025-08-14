#!/usr/bin/env ruby
# Angalia: A Remote Elder Monitoring System Client
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#
# ------------------------------------------------------------
# angalia_app.rb  -- starting point for sinatra web app
# Assumes AngaliaWork and Environ are loaded via config.ru and available globally
# through the ANGALIA constant.
# ------------------------------------------------------------

require 'sinatra'
require 'haml'
require_relative 'tag_helpers'
require 'sinatra/form_helpers' # Useful forms on the home or status page
require 'rack-flash' # displaying success/error messages to the user
require 'yaml'       # FUTURE: use by Environ for configuration loading
require 'thread'     # Mutex
require_relative 'angalia_error' # Required for AngaliaError, LivestreamForceStopError

# +++++++++++++++++++++++++++++++++++++++++++++++++
module Angalia # Angalia Namespace
# +++++++++++++++++++++++++++++++++++++++++++++++++

class AngaliaApp < Sinatra::Application
  helpers Sinatra::AssetHelpers # Explicitly include your AssetHelpers

  enable :sessions
  use Rack::Flash

  set :root, File.dirname(__FILE__)
  set :views, File.join(File.dirname(__FILE__), 'views') # Explicitly set views directory
  
 # Disable show_exceptions in development to ensure 'error do' block is hit
 # set :show_exceptions, false # used for testing

  # MUTEX SYNCED VALUES =======================================================
  @@livestream_client_count = 0  # global livestream user counter
  @@is_jitsimeeting = false # Initialize the Jitsi meeting flag
  @@active_livestream_thread = nil  # Tracks livestream service thread
  @@livestream_mutex = Mutex.new    # syncs flag access/updates
  # =============================================================================

  # ------------------------------------------------------------
  # Web Server Routes
  # ------------------------------------------------------------

  # ------------------------------------------------------------
  # GET /
  # Home Page
  # Displays the main caregiver control panel with action buttons.
  # ------------------------------------------------------------
  get '/' do
    # MUTEX BLOCK =======================================================
    @@livestream_mutex.synchronize do
      @is_livestream = (@@livestream_client_count > 0 && !@@is_jitsimeeting)
    end
    # MUTEX BLOCK =======================================================
    haml :index
  end # get /

  get '/disclaimers' do
    haml :disclaimers
  end

  get '/about' do
    haml :about
  end

  # ------------------------------------------------------------
  # GET /webcam_stream
  # View Webcam Stream
  # Serves a continuous MJPEG stream from the Angalia webcam.
  # ------------------------------------------------------------
  # Uses Sinatra's streaming capabilities to send continuous data.
  # ------------------------------------------------------------
  # A more robust implementation would parse for 0xFFD8 (start) and 0xFFD9 (end) markers.
  # For this initial implementation, we'll assume ANGALIA.get_webcam_frame
  # handles reading a complete frame from the pipe.
  # ------------------------------------------------------------
  get '/webcam_stream' do
    # Set the Content-Type header for MJPEG streaming.
    content_type 'multipart/x-mixed-replace; boundary=--BoundaryString'

    # MUTEX BLOCK =======================================================
    # Acquire a lock to safely modify the client count
    @@livestream_mutex.synchronize do
      # Deny access if a Jitsi meeting is currently active
      if @@is_jitsimeeting
        Environ.log_info("App: Denying livestream request; Jitsi meeting is active.")
        flash[:notice] = "Video meeting is active; Livestream unavailable."
        redirect '/'
     end

      if @@livestream_client_count >= 1
        Environ.log_info("App: Denying livestream request; stream already active for another client.")
        flash[:notice] = "Livestream already active for another client."
        redirect '/'
      end
      @@livestream_client_count += 1
      Environ.log_info("App: Livestream client connected. Count: #{@@livestream_client_count}")
      @@active_livestream_thread = Thread.current  # current thread servicing livestream
    end  # mutex lock
    # MUTEX BLOCK =======================================================

    stream do |out|
      begin
        # Check if streaming is active; start it if not.
        ANGALIA.start_livestream(@@livestream_client_count)

        # Continuously read and send frames.
        loop do
          # Retrieve the frame data from the Webcam singleton.
          frame_data = ANGALIA.get_livestream_frame
          
          if frame_data
            out << "--BoundaryString\r\n"
            out << "Content-Type: image/jpeg\r\n"
            out << "Content-Length: #{frame_data.length}\r\n"
            out << "\r\n"
            out << frame_data
            out << "\r\n"
          else
            # If no frame is available, wait briefly to prevent busy-waiting.
            sleep 0.1    # The sleep duration can be tuned.
          end  # fi .. if

        end  # continuous frame-reading loop 
        
        # RESCUE BLOCK =======================================================
      rescue IOError, Errno::EPIPE => e
        # Handle client disconnection or pipe errors gracefully.
        Environ.log_warn "Webcam stream client disconnected / pipe error: #{e.message}"
      rescue Angalia::LivestreamForceStopError => e
        # This is the expected exception when /weboff forces the stream to stop
        Environ.log_info "App: Livestream forced to stop: #{e.message}"
      rescue => e
        # Catch any other unexpected errors during streaming.
        Environ.log_error "Error streaming webcam: #{e.message}"

      ensure
        # MUTEX BLOCK =======================================================
        # IMPORTANT: Ensure the counter is decremented and webcam is stopped on stream end/error
        @@livestream_mutex.synchronize do
          if @@livestream_client_count > 0
            @@livestream_client_count -= 1
            Environ.log_info("App: Livestream disconnected; #{@@livestream_client_count} users remaining")
            # Tell AngaliaWork/Webcam to stop the stream if no clients remain
            ANGALIA.stop_livestream(@@livestream_client_count)
          else
            Environ.log_warn("App: Disconnect livestream but users already 0")
          end  # fi .. else.. if
          # Clear the active livestream thread reference
          @@active_livestream_thread = nil
        end  # mutex block
          # MUTEX BLOCK =======================================================

      end  # rescue block

        # END RESCUE BLOCK =======================================================

    end   # stream do out block

  end  # get /webcam_stream
  # ------------------------------------------------------------

  # ------------------------------------------------------------
  # GET /start_meet
  # Start Jitsi Meet Session
  # Triggers the Angalia system to initiate a Jitsi Meet session.
  # ------------------------------------------------------------
  get '/start_meet' do

   # MUTEX BLOCK =======================================================
   # Proactively reset the livestream client count in AngaliaApp
   @@livestream_mutex.synchronize do
     if @@livestream_client_count > 0
       Environ.log_info("App: Resetting livestream client count from #{@@livestream_client_count} to 0 due to Meet session start.")
       @@livestream_client_count = 0
       # Force stop the active livestream thread if it exists
       if @@active_livestream_thread && @@active_livestream_thread.alive?
         Environ.log_warn("App: Signalling active livestream thread to terminate due to Meet start.")
         @@active_livestream_thread.raise(Angalia::LivestreamForceStopError, "Meet session started.")
       end
     end  # reset livestream count
     @@is_jitsimeeting = true # Set Jitsi meeting flag to true
   end  # mutex
   # MUTEX BLOCK =======================================================

   start_thread = Thread.new do
     begin
       if ANGALIA.start_meet
         Environ.log_info "HUB: Jitsi Meet session initiated as background task."
       else
         Environ.log_error "HUB: Jitsi Meet failed to initiate as background task.."
       end

      # RESCUE BLOCK =======================================================
     rescue ConfigurationError => e
       Environ.log_error "HUB: start_meet configuration error (background task): #{e.message}"
       
     rescue OperationError => e
       Environ.log_error "HUB: Operation error, start_meet (background task): #{e.message}"
       
     rescue => e
       Environ.log_error "HUB: unexpected error starting Jitsi Meet (background task): #{e.message}"
       
     end # begin
      # END RESCUE BLOCK ===================================================

   end # Thread.new

   # start_thread.join   # waits for completion

   flash[:notice] = "Starting video meeting..."
   redirect '/' # Redirect to the home page immediately

 end # get /start_meet

 # ------------------------------------------------------------
 # GET /end_meet
 # End Jitsi Meet Session
 # Triggers the Angalia system to terminate the active Jitsi Meet session.
 # ------------------------------------------------------------
 get '/end_meet' do

   stop_thread = Thread.new do
     begin
       if ANGALIA.end_meet
         Environ.log_info "HUB: Video Meet terminated in background."
       else
         Environ.log_error "HUB: Video Meet failed to terminate in background."
       end

        # RESCUE BLOCK =======================================================
     rescue ConfigurationError => e
       Environ.log_error "HUB: Configuration error during end_meet (background task): #{e.message}"
       
     rescue OperationError => e
       Environ.log_error "HUB: Operation error during end_meet (background task): #{e.message}"
       
     rescue => e
       Environ.log_error "HUB: Unexpected error at end_meet (background task): #{e.message}"
     end 
        # END RESCUE BLOCK =======================================================

    ensure
      # MUTEX BLOCK =======================================================
      @@livestream_mutex.synchronize do
        @@is_jitsimeeting = false # Reset Jitsi meeting flag to false
        Environ.log_info("App: Jitsi meeting flag set to false.")
      end  # MUTEX
      # MUTEX BLOCK =======================================================

   end # Thread.new

   # stop_thread.join   # waits for completion

   flash[:notice] = "Terminating video meeting..."
   redirect '/' # Redirect to the home page immediately

 end # get /end_meet

  # ------------------------------------------------------------
  # GET /weboff
  # Forces the livestream to stop and resets client count to zero.
  # This provides a manual override to stop the stream.
  # ------------------------------------------------------------
  get '/weboff' do
    # MUTEX BLOCK =======================================================
    @@livestream_mutex.synchronize do
      Environ.log_warn("App: '/weboff' Forcing livestream off; (#{@@livestream_client_count})")
      @@livestream_client_count = 0
      #
      # Force terminate the active livestream thread if it exists
      if @@active_livestream_thread && @@active_livestream_thread.alive?
        Environ.log_warn("App: Terminate-Signal livestream thread /weboff")
        @@active_livestream_thread.raise(Angalia::LivestreamForceStopError, "Forced stop via /weboff")
      end  # force stop to livestream listener
    end  # mutex
    # MUTEX BLOCK =======================================================
    
    begin
      ANGALIA.stop_livestream(0) # Signal AngaliaWork to stop the stream unconditionally
      flash[:notice] = "Livestream has been forced OFF."
    rescue AngaliaError::WebcamOperationError => e
      flash[:error] = "Error forcing livestream off: #{e.message}"
      Environ.log_error("App: Error in /weboff: #{e.message}")
    rescue => e
      flash[:error] = "An unexpected error occurred forcing livestream off: #{e.message}"
      Environ.log_error("App: Unexpected error in /weboff: #{e.message}")
    end

    redirect '/'
  end # get /weboff


  # ------------------------------------------------------------
  # GET /status
  # View System Status (Developer/Debug)
  # Displays current system status information for debugging/monitoring.
  # ------------------------------------------------------------
  get '/status' do
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
