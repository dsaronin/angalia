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
#----------------------------------------------------------

class Environ
  include Singleton
  
# constants ... #TODO replace with config file?
  APP_NAME = "Angalia"
  APP_NAME_HEAD = APP_NAME + ": "
  ANGALIA_VERSION = "0.03"
  ANGALIA_HELP = "flags (f), options (o), help (h), version (v), quit (q), exit (x)" +
    "start meet (s), end meet (e), webcam (w), camctl (c)"
  #  ------------------------------------------------------------
  EXIT_CMD  = "q"  # default CLI exit command used if EOF
  #  ------------------------------------------------------------
 
# initialize the class-level instance variables
  @angalia_version = ANGALIA_VERSION
  @app_name = APP_NAME 
  @app_name_head = APP_NAME_HEAD 
  @angalia_help = ANGALIA_HELP 


  class << self   
        # mixin AnsiColor Module to provide prettier ansi output
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

end  # Class Environ

class MajorError < StandardError
  def initialize(msg="Something not found")
    super(msg)
  end
end

class MinorError < StandardError
  def initialize(msg="Something not done")
    super(msg)
  end
end
