# Angalia: A Remote Elder Monitoring System Client
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#
# class AngaliaWork -- top-level control for doing everything
# accessed either from the CLI controller or the WEB i/f controller
#

class AngaliaWork
  require_relative 'environ'
  require_relative 'flash_manager'
 
  #  ------------------------------------------------------------
  #  initialize  -- creates a new object
  #  ------------------------------------------------------------
  def initialize()
    @my_env    = Environ.instance   # currently not used anywhere
  end

  #  ------------------------------------------------------------
  #  setup_work  -- handles initializing angalia system
  #  ------------------------------------------------------------
  def setup_work()
    Environ.log_info( "starting..." )
    # Environ.put_info FlashManager.show_defaults
  end

  #  ------------------------------------------------------------
  #  shutdown_work  -- handles pre-termination stuff
  #  ------------------------------------------------------------
  def shutdown_work()
    Environ.log_info( "...ending" )
  end
 
  #  ------------------------------------------------------------
  #  do_status  -- display list of all angalia rules
  #  ------------------------------------------------------------
  def do_status
    sts = ""
    Environ.put_info ">>>>> status:  " + sts
    return sts
  end

  #  ------------------------------------------------------------
  #  do_flags  -- display flag states
  #  args:
  #    list  -- cli array, with cmd at top
  #  ------------------------------------------------------------
  def do_flags(list)
    list.shift  # pop first element, the "f" command
    if ( Environ.flags.parse_flags( list ) )
      Environ.change_log_level( Environ.flags.flag_log_level )
    end

    sts = Environ.flags.to_s
    Environ.put_info ">>>>>  flags: " + sts
    return sts
  end

  #  ------------------------------------------------------------
  #  do_help  -- display help line
  #  ------------------------------------------------------------
  def do_help
    sts = Environ.angalia_help + "\n" + Environ.flags.to_help 
    Environ.put_info sts
    return sts
  end

  #  ------------------------------------------------------------
  #  do_version  -- display angalia version
  #  ------------------------------------------------------------
  def do_version        
    sts = Environ.app_name + " v" + Environ.angalia_version
    Environ.put_info sts  
    return sts
  end

  #  ------------------------------------------------------------
  #  do_options  -- display any options
  #  ------------------------------------------------------------
  def do_options        
    sts = ">>>>> options "
    Environ.put_info  sts  
    return sts
  end

  #  ------------------------------------------------------------
  #  do_flashcards  -- intiates flashcard handling
  #  returns: self obj or nil if exception
  #  ------------------------------------------------------------
  def do_flashcards( list, settings )
    begin
      return FlashManager.new( list.first, settings )
    rescue TopicError
      Environ.put_and_log_error( ">>  " + $!.message )
    rescue EntryError
      Environ.put_and_log_error( ">>  " + $!.message )
    end  # exception handling

    return nil
  end


  #  ------------------------------------------------------------
  #  ------------------------------------------------------------

end  # class AngaliaWork

