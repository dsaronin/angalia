# Angalia: A Remote Elder Monitoring Hub
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#
# class Flags -- maintains application's trace, logging, execution flags
#

class Flags

  #  ------------------------------------------------------------
  #  flags default initial settings
  #
  RENDER_PDF      = false # true if render as pdf
  CLI_OUTPUT      = true  # output to console
  LOG_LEVEL_QUIET    = Logger::WARN 
  LOG_LEVEL_INFO     = Logger::INFO  
  LOG_LEVEL_VERBOSE  = Logger::DEBUG 

  #  ------------------------------------------------------------
  #  flag names (keys into hash)
  #
  FLAG_LOG_LEVEL         = "z"
  FLAG_RENDER_PDF        = "r"
  FLAG_CLI_OUTPUT        = "o"

  #  ------------------------------------------------------------
  #  ------------------------------------------------------------
  #  ------------------------------------------------------------
  #  ------------------------------------------------------------

  #  ------------------------------------------------------------
  #  new  -- creates a new object with the flags hash set to defaults
  #  ------------------------------------------------------------
  def initialize()
    @flags = {
      FLAG_LOG_LEVEL         =>  LOG_LEVEL_QUIET,
      FLAG_RENDER_PDF        =>  RENDER_PDF,
      FLAG_CLI_OUTPUT        =>  CLI_OUTPUT
    }
  end

  #  ------------------------------------------------------------
  #  to_s -- converts flags to a display string
  #  ------------------------------------------------------------
  def to_s
    str = ""
    @flags.each do |flag, setting|
      str <<= sprintf( "%1s - %1s, ", flag, setting )
    end
    return str
  end

  #  ------------------------------------------------------------
  #  to_help -- creates a help line to explain flags
  #  ------------------------------------------------------------
  def  to_help
    return  "flags: " + 
      FLAG_LOG_LEVEL + "--verbose/quiet logging, "  +
      FLAG_RENDER_PDF + "--render pdf, "  + 
      FLAG_CLI_OUTPUT + "--output to console"
  end

  #  ------------------------------------------------------------
  #  parse_flags -- parse a cli flag command
  #  possbilities: "+g -p z", "-gvc", "- gv cp"
  #  + makes a flag true (default), - makes it false
  #  but if the flag is seperated by a space, it's ignored
  #  returns true if log_level changed
  #  ------------------------------------------------------------
  def parse_flags( list )
    fvalue = true   # default flag value is true
    was_log_level = @flags[FLAG_LOG_LEVEL]

    list.each do |token|
      token.split("").each do |flg|
        case flg
        when /\+/ then fvalue = true
        when /\-/ then fvalue = false
        when /z/i then @flags[FLAG_LOG_LEVEL] = ( fvalue  ?  LOG_LEVEL_QUIET : LOG_LEVEL_VERBOSE )
        when /[ro]/i then @flags[flg] = fvalue
        else
          Environ.log_info( "parse_flags unrecognized flag: #{flg}" )
          # nop; ignore flag
        end   # case
      end   # each flag
    end  # list of tokens

    return ( was_log_level != @flags[FLAG_LOG_LEVEL] )

  end

  #  ------------------------------------------------------------
  #  flag_xxx_yyyy  -- getters for each of the flags
  #  ------------------------------------------------------------

  def flag_log_level
    @flags[FLAG_LOG_LEVEL]
  end

  def flag_render_pdf
    @flags[FLAG_RENDER_PDF]
  end

  def flag_cli_output
    @flags[FLAG_CLI_OUTPUT]
  end

  #  ------------------------------------------------------------
  #  ------------------------------------------------------------

end   # flags
