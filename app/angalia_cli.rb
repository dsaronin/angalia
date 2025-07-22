# DrillTutor: A Drill Sergent for language students
# Copyright (c) 2023 David S Anderson, All Rights Reserved
#
# class AngaliaCLI -- 'controller' for CLI
#

class AngaliaCLI
  require_relative 'hocasi_work'

    ANGALIA = AngaliaWork.new 

  #  ------------------------------------------------------------
  #  cli  -- #  CLI entry point
  #  ------------------------------------------------------------
  def cli()
    ANGALIA.setup_work()    # initialization of everything
    Environ.put_message "\n\t#{ Environ.app_name }: A Drill Sergent for language learners.\n"

    do_work()      # do the work of çekimi

    ANGALIA.shutdown_work()

    return 1
  end

  #  ------------------------------------------------------------
  #  do_work  -- handles primary hocasi stuff
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

      when  "x", "exit"      then  loop = false  # exit program
      when  "q", "quit"      then  loop = false  # exit program

      when  ""               then  loop = true   # empty line; NOP
      else     
        fc_player( cmdlist )
    end  # case

    return loop
    end

  #  ------------------------------------------------------------
  #  fc_player -- cli player control i/f
  #  ------------------------------------------------------------
  def fc_player( cmdlist )
    player = ANGALIA.do_flashcards( cmdlist, nil ).start_card_player
    
    unless player.nil?
      # player output ctl 
      (loop, show) = player.commands( ["c"]  )

      begin
        Environ.put_data "\t" + show[0] unless show.empty?
        Environ.put_prompt("\nPlayer > ")  
        (loop, show) = player.commands( Environ.get_input_list )
      end  while loop 

    end  # player not nil
   end

  #  ------------------------------------------------------------
  #  ------------------------------------------------------------
end  # class

