# Angalia: A Remote Elder Monitoring Hub
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#
# class Environ -- sets up & control environment for application
# SINGLETON: invoke as Environ.instance
#
#----------------------------------------------------------
# requirements
#----------------------------------------------------------
  require 'logger'
  require_relative 'ansicolor'
  require 'singleton'
  require_relative 'flags'
  require_relative 'version'
  
#----------------------------------------------------------
# +++++++++++++++++++++++++++++++++++++++++++++++++
module Angalia              # Define the top-level module  Angalia::
# +++++++++++++++++++++++++++++++++++++++++++++++++

class Environ
  include Singleton
  
# constants ... #TODO replace with config file?
  APP_NAME = "Angalia"
  APP_NAME_HEAD = APP_NAME + ": "
  ANGALIA_HELP = "flags (f), options (o), help (h), version (v), quit (q), exit (x)" +
    "start meet (s), end meet (e), webcamon (wo), webcamoff (wf), showpipe (sp), showsframe (sf)"
  #  ------------------------------------------------------------
  EXIT_CMD  = "q"  # default CLI exit command used if EOF
  #  ------------------------------------------------------------
  IS_DEVELOPMENT = ( ENV['SINATRA_ENV'] == "development" )
  DEBUG_VPN_OFF =  (ENV['DEBUG_ENV']  == "true" )
  DEBUG_MODE =  (ENV['DEBUG_ENV'] == "true"  )
  SKIP_VPN_CONNECT = (ENV['SKIP_HUB_VPN']  == "true" )

  #  ------------------------------------------------------------
  #  GLOBAL CONSTANTS
  #  ------------------------------------------------------------
  # angalia-hub named devices
  #  ------------------------------------------------------------
  MY_MONITOR_DISPLAY_NAME  = "HDMI-A-0" # Default/initial monitor name
  DEV_MONITOR_DISPLAY_NAME = "HDMI-A-0" # Dev monitor name
  MY_WEBCAM_NAME = "video0"   # default webcam /dev name
  MY_SPEAKERS = "alsa_output.usb-Generic_USB2.0_Device_20121120222012-00.analog-stereo"
  MY_MIC = "alsa_input.usb-046d_0825_AA3F0D40-02.mono-fallback"

  #  ------------------------------------------------------------
  #  video conferencing
  #  ------------------------------------------------------------
  MY_JITSI_MEET_ROOM = "https://jitsi.vpn.local/angalia#config.prejoinPageEnabled=false"
  CHROMIUM_USER_DATA_DIR = File.expand_path("~/.angalia/chromium_profile")
  #  ------------------------------------------------------------
  #  vpn client stuff
  #  ------------------------------------------------------------
  ANGALIA_VPN_CLIENT = "malagarasi-client"
  OPENVPN_CLIENT_CONFIG_PATH = "/home/daudi/certs/malagarasi-client.ovpn"
  VPN_RETRY_COUNT = 3 # Example: Retry 3 times
  VPN_SLEEP_COUNT = 5 # value for sleep before checking
  #  ------------------------------------------------------------
  #  livestream pipe stuff
  #  ------------------------------------------------------------
  WEBCAM_PIPE = "CAMOUT"
  WEBCAM_PIPE_PATH = "/tmp/#{WEBCAM_PIPE}"
  WEBCAM_READ_TIMEOUT_SECONDS  = 0.5

  #  ------------------------------------------------------------
  # class-level instance variables
  #  ------------------------------------------------------------
  @angalia_version = Angalia::VERSION
  @app_name = APP_NAME 
  @app_name_head = APP_NAME_HEAD 
  @angalia_help = ANGALIA_HELP 
  #  ------------------------------------------------------------

  class << self   
        # mixin Angalia::AnsiColor Module to provide prettier ansi output
        # makes all methods in AnsiColor become Environ class methods
    include AnsiColor
        # makes the following class-level instance variables w/ accessors
    attr_accessor :angalia_version, :app_name, :app_name_head, :angalia_help
  end
  
  #  ------------------------------------------------------------
  #  logger setup
  #  ------------------------------------------------------------
  @@logger = Logger.new(STDERR)
  @@logger.level = Flags::LOG_LEVEL_INFO
  
  #  ------------------------------------------------------------
  #  Flags setup
  #  ------------------------------------------------------------
  @@myflags = Flags.new()

  #  ------------------------------------------------------------
  #  change_log_level  -- changes the logger level
  #  args:
  #    level -- Logger level: DEBUG, INFO, WARN, ERROR
  #  ------------------------------------------------------------

  def Environ.change_log_level( level )
    @@logger.level = level
  end

  #  ------------------------------------------------------------
  #  flags  -- returns the Environ-wide flags object
  #  ------------------------------------------------------------
  def Environ.flags()
    return @@myflags
  end

  #  ------------------------------------------------------------
  # log_debug -- wraps a logger message in AnsiColor & app name
  #  ------------------------------------------------------------
  def Environ.log_debug( msg )
    @@logger.debug wrapYellow app_name_head + msg
  end

  #  ------------------------------------------------------------
  # log_info -- wraps a logger message in AnsiColor & app name
  #  ------------------------------------------------------------
  def Environ.log_info( msg )
    @@logger.info wrapCyan app_name_head + msg
  end

  #  ------------------------------------------------------------
  # log_warn -- wraps a logger message in AnsiColor & app name
  #  ------------------------------------------------------------
  def Environ.log_warn( msg )
    @@logger.warn wrapGreen app_name_head + msg
  end

  #  ------------------------------------------------------------
  # log_error -- wraps a logger message in AnsiColor & app name
  #  ------------------------------------------------------------
  def Environ.log_error( msg )
    @@logger.error wrapRed APP_NAME_HEAD + msg
  end

  #  ------------------------------------------------------------
  # log_fatal -- wraps a logger message in AnsiColor & app name
  #  ------------------------------------------------------------
  def Environ.log_fatal( msg )
    @@logger.fatal wrapRedBold app_name_head + msg
  end

  
  #  ------------------------------------------------------------
  # get_input_list  -- returns an array of input line arguments
  # arg:  exit_cmd -- a command used if EOF is encountered; to force exit
  # input line will be stripped of lead/trailing whitespace
  # will then be split into elements using whitespace as delimiter
  # resultant non-nil (but possibly empty) list is returned
  #  ------------------------------------------------------------
  def Environ.get_input_list( exit_cmd = EXIT_CMD )
    # check for EOF nil and replace with exit_cmd if was EOF
    return  (gets || exit_cmd ).strip.split
  end

  #  ------------------------------------------------------------
  #  put_and_log_error -- displays the error and logs it
  #  ------------------------------------------------------------
  def Environ.put_and_log_error( str )
    self.put_error( str )
    self.log_error( str )
  end
  
  #  ------------------------------------------------------------
  #  ------------------------------------------------------------
  def self.jitsi_meet_room_url
    return MY_JITSI_MEET_ROOM
  end

  #  ------------------------------------------------------------
  #  ------------------------------------------------------------
  def self.to_sts
    return "dev: #{IS_DEVELOPMENT}, debug: #{DEBUG_VPN_OFF}, vpn: #{DEBUG_MODE}"
  end

  # ------------------------------------------------------------
  # my_monitor_default -- Returns default monitor display name
  # ------------------------------------------------------------
  def self.my_monitor_default
     return MY_MONITOR_DISPLAY_NAME
  end

  #  ------------------------------------------------------------
  #  ------------------------------------------------------------
end  # Class Environ
  
end  # module Angalia
