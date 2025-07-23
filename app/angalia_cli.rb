# Angalia: A Remote Elder Monitoring Hub
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#
# class AngaliaCLI -- 'controller' for CLI
#

class AngaliaCLI
  require_relative 'angalia_work'

    ANGALIA = AngaliaWork.new 

  #  ------------------------------------------------------------
  #  cli  -- #  CLI entry point  <==== kicks off command loop
  #  ------------------------------------------------------------
  def cli()
    ANGALIA.setup_work()    # initialization of everything
    Environ.put_message "\n\t#{ Environ.app_name }: Remote Elder Monitoring Hub.\n"

    do_work()      # do the work of angalia

    ANGALIA.shutdown_work()

    return 1
  end

  #  ------------------------------------------------------------
  #  do_work  -- handles primary angalia stuff
  #  CLI usage only
  #  ------------------------------------------------------------
  def do_work()
      # loop for command prompt & user input
    begin
      Environ.put_prompt("\n#{ Environ.app_name } > ")  
    end  while  parse_commands( Environ.get_input_list )
  end

  #  ------------------------------------------------------------
  #  parse_commands  -- command interface
  #  ------------------------------------------------------------
  def parse_commands( cmdlist )        
    loop = true                 # user input loop while true

        # parse command
    case ( cmdlist.first || ""  ).chomp

      when  "f", "flags"     then  ANGALIA.do_flags( cmdlist )     # print flags
      when  "h", "help"      then  ANGALIA.do_help      # print help
      when  "v", "version"   then  ANGALIA.do_version   # print version
      when  "o", "options"   then  ANGALIA.do_options   # print options

      when  "s", "start"     then  ANGALIA.start_meet  # start Jitsi-meeting
      when  "e", "end"       then  ANGALIA.end_meet  # end Jitsi-meeting
      when  "w", "webcam"    then  ANGALIA.webcam    # start webcam feed

      when  "x", "exit"      then  loop = false  # exit program
      when  "q", "quit"      then  loop = false  # exit program

      when  ""               then  loop = true   # empty line; NOP

      else     
        Environ.log_warn( "unknown command" ) 

    end  # case

    return loop
    end

  #  ------------------------------------------------------------
  #  ------------------------------------------------------------

  #  ------------------------------------------------------------
  #  ------------------------------------------------------------
end  # class

