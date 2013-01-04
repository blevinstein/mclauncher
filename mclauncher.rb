require 'sinatra/base'
require 'sinatra/contrib'

require 'haml'

require './config.rb'

class MCLauncher < Sinatra::Base
  set :port, ENV['PORT'] || 4567
  set :environment, $environment
  enable :sessions

  set :haml, :layout => :template
  register Sinatra::Contrib
  
  def require_auth
    redirect '/login' unless session[:user]
  end

  get '/login' do
    redirect '/' if session[:user]
    haml :login, :locals => {:flash => nil}
  end

  post '/login' do
    user = User.get(params[:username])
    if user && user.password?(params[:password])
      session[:user] = user.username
      redirect '/'
    else
      haml :login, :locals => {:flash => "Incorrect username or password."}
    end
  end

  get '/logout' do
    session[:user] = nil
    redirect '/'
  end

  get '/account' do
    require_auth
    haml :account, :locals => {:flash => nil, :user=>User.get(session[:user])}
  end

  post '/aws' do
    require_auth
    if params[:access_key_id] && params[:secret_access_key]
      #ec2 = AWS::EC2.new(:access_key_id => params[:access_key_id],
      #                   :secret_access_key => params[:secret_access_key])
      user = User.get(session[:user])
      user.access_key_id = params[:access_key_id]
      user.secret_access_key = params[:secret_access_key]
      user.save
    end
    redirect '/account'
  end

  post '/server' do
    require_auth
    if params[:start]
      user = User.get(session[:user])
      server = Server.new
      server.user = user
      server.start
      server.save
    elsif params[:stop]
      server = Server.get(params[:instance_id])
      fail if server.user.username != session[:user]
      server.stop
    end
    redirect '/'
  end

  get '/' do
    require_auth
    Server.each do |server|
      server.destroy if server.status == :terminated
    end
    haml :index
  end

  run! if app_file == $0
end
