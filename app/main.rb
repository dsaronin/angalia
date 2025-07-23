#!/usr/bin/env ruby
#
# Angalia: A Remote Elder Monitoring Hub
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#
# main.rb -- starting point for linux CLI implementation
#
# make sure to run $ bundle install  the first time
# To Run:
# make this file executable: chmod +x main.rb
# $ ~/main.rb
#

  require_relative 'angalia_cli'

  exit AngaliaCLI.new.cli   # <-- cli() is the entry point

