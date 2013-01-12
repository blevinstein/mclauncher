require 'sinatra/base'
require 'sinatra/contrib'

require 'haml'

require 'rufus/scheduler'

require './config.rb'

class MCLauncher < Sinatra::Base
  set :port, ENV['PORT'] || 4567
  set :environment, $environment
  set :scheduler, Rufus::Scheduler.start_new
  enable :sessions

  set :haml, :layout => :template
  register Sinatra::Contrib

  before do
    @flash = session[:flash]
    session[:flash] = nil
  end
  
  def require_auth
    redirect '/login' unless session[:user]
    @user = User.get(session[:user])
    fail if @user.nil?
  end

  get '/login' do
    redirect '/' if session[:user]
    haml :login
  end

  post '/login' do
    user = User.get(params[:username])
    if user && user.password?(params[:password])
      session[:user] = user.username
      redirect '/'
    else
      @flash = 'Incorrect username or password.'
      haml :login
    end
  end

  get '/logout' do
    session[:user] = nil
    redirect '/'
  end

  get '/account' do
    require_auth
    haml :account, :locals => {:user=>@user}
  end

  post '/aws' do
    require_auth
    if params[:access_key_id] && params[:secret_access_key]
      @user.set_aws_keys(params[:access_key_id], params[:secret_access_key])
      session[:flash] = 'Updated AWS keys!'
    end
    redirect '/account'
  end

  post '/server' do
    require_auth
    if params[:start]
      server = Server.create(@user)
      session[:flash] = 'Server starting.'
    end
    redirect '/'
  end

  post '/server/:instance_id' do
    require_auth
    server = Server.get(params[:instance_id])
    fail if server.user != @user
    if params[:start]
      server.start
      session[:flash] = 'Server starting.'
    elsif params[:stop]
      server.stop
      session[:flash] = 'Server stopping.'
    elsif params[:term]
      server.destroy
      session[:flash] = 'Server terminating.'
    end
    redirect '/'
  end

  get '/' do
    require_auth
    @user.servers.each do |server|
      server.destroy if server.status == :terminated
    end
    haml :index, :locals => {:user=>@user}
  end

  run! if app_file == $0
end
