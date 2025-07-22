#!/usr/bin/env ruby
# Angalia: A Remote Elder Monitoring System Client
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#
# angalia_app.rb  -- starting point for sinatra web app
#

  require 'sinatra'
  # require_relative 'player'
  require 'sinatra/form_helpers'
  require 'rack-flash'
  require 'yaml'

class AngaliaApp < Sinatra::Application

  enable :sessions
  use Rack::Flash

  set :root, File.dirname(__FILE__)

  #  ------------------------------------------------------------
  #  ------------------------------------------------------------

  get '/' do
    haml :index
  end

  get '/source' do
    helper_get_settings
    @key_list = Module.const_get( @settings[:source] ).sorted_keys
    @settings[:entry] ||= @key_list.first
    @entry_def = @settings[:entry].to_sym
    haml :source
  end

  get '/lessons/def' do
    helper_prep_lessons( true )
  end

  get '/lessons/p' do     # prev page (if any)
    helper_prep_lessons(false, -1)
  end

  get '/lessons/n' do     # next page (if any)
    helper_prep_lessons(false, 1)
  end

  get '/lessons' do
    helper_prep_lessons
  end

  get '/disclaimers' do
    haml :disclaimers
  end

  get '/about' do
    haml :about
  end

  get '/settings' do
    helper_get_settings
    haml :settings
  end

  get '/rear' do
    # toggle rear show/hide state
    @rear_toggle = true   # acts as a global; will be seen by helpers
    helper_do_player( Player::PCMD_CURR )
  end

  get '/auxfc/:path' do
    helper_start_player( helper_load_path )
  end

  get '/auxlist/:path' do
    helper_prep_lists( helper_load_path )
  end

  #  ------------------------------------------------------------
  #  ------------------------------------------------------------
  get '/start' do
    helper_start_player
  end  # /start

  get '/next' do
    helper_do_player( Player::PCMD_NEXT )
  end

  get '/prev' do
    helper_do_player( Player::PCMD_PREV )
  end

  get '/curr' do
    helper_do_player( Player::PCMD_CURR )
  end

  get '/shfl' do
    helper_do_player( Player::PCMD_SHUFFLE )
  end

  get '/unsh' do
    helper_do_player( Player::PCMD_UNSHFLE )
  end

  get '/reset' do
    helper_do_player( Player::PCMD_RESET )
  end

  get '/gnext' do
    helper_do_player( Player::PCMD_NEXT_GRP )
  end

  get '/gprev' do
    helper_do_player( Player::PCMD_PREV_GRP )
  end

  get '/ghead' do
    helper_do_player( Player::PCMD_GHEAD )
  end

  get '/flip' do
    helper_do_player( Player::PCMD_FLIP )
  end

  get '/quit' do
    helper_do_player( Player::PCMD_QUIT )
  end

  #  ------------------------------------------------------------
  #  ------------------------------------------------------------
  get '/lists' do
    helper_prep_lists
    haml :lists
  end  # /lists


  #  ------------------------------------------------------------
  #  ------------------------------------------------------------

  post '/settings' do
    # pp request.env
    parms = params[:settings]
    settings = {
        :topic    => parms[:topic],
        :source   => parms[:source],
        :selector => parms[:order],
        :sizer    => parms[:sizer].to_i,
        :side     => parms[:side]
      }

    helper_player_or_list(params[:submit], settings)
  end


  #  ------------------------------------------------------------
  #  ------------------------------------------------------------

  post '/source' do
    parms = params[:source]
    helper_get_settings
    @settings[:entry] = parms[:entry]
    helper_player_or_list(params[:submit], @settings)
  end

  #  ------------------------------------------------------------
  #  ------------------------------------------------------------
end  # HocasiApp 
