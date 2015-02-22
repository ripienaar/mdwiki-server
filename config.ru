#!/usr/bin/ruby

require 'sinatra'
require 'omniauth-clef'
require 'filelock'

configure do
  if ENV["WIKI_ROOT"]
    set :public_folder, ENV["WIKI_ROOT"]
  else
    set :public_folder, Proc.new { File.join(root, "wiki") }
  end

  unless ENV["LOCAL_DEV"] == "1"
    ["SESSION_SECRET", "CLEF_APP_ID", "CLEF_SECRET", "CLEF_USERS"].each do |v|
      next if ENV.include?(v)

      raise("%s needs to be set in the environment for this app to function" % v)
    end

    use Rack::Session::Cookie, :key => 'rack.session',
                               :expire_after => 86400,
                               :secret => ENV["SESSION_SECRET"]

    use OmniAuth::Builder do
      provider :clef, ENV['CLEF_APP_ID'], ENV['CLEF_SECRET']
    end
  end
end

helpers do
  def root_file
    ENV["ROOT_FILE"] || "mdwiki.html"
  end

  def valid_user?(user)
    users = ENV["CLEF_USERS"].split(",")
    return true if users.include?("*")
    return true if users.include?(user.to_s)
    return false
  end

  def current_user
    ENV["LOCAL_DEV"] == "1" || !session[:uid].nil?
  end

  def git_update_content
    Filelock("/tmp/update_hook") do
      Dir.chdir(settings.public_folder) do
        `git pull origin master 2>&1`
      end
    end
  end
end

before do
  pass if request.path_info =~ /^\/auth\//
  pass if request.path_info =~ /^\/hooks\//

  redirect to('/auth/clef') unless current_user
end

get '/auth/clef/callback' do
  redirect("/auth/failure?uid=%s" % env['omniauth.auth']['uid']) unless valid_user?(env['omniauth.auth']['uid'])

  session[:uid] = env['omniauth.auth']['uid']
  redirect to('/')
end

get '/auth/failure' do
  "Authentication failed for user id %s" % params["uid"]
end

if ENV["HOOKS"] == "1"
  unless ENV["HOOK_SIMPLE"] == "0"
    get '/hooks/simple' do
      "<pre>" + git_update_content + "</pre>"
    end
  end

  unless ENV["HOOK_GITHUB"] == "0"
    post '/hooks/github' do
      hook_params = JSON.parse(request.body.read)

      if hook_params["ref"] == "refs/heads/master"
        puts("Received github hook for ref %s on repository %s" % [hook_params["ref"], hook_params["repository"]["full_name"]])
        "<pre>" + git_update_content + "</pre>"
      end
    end
  end

  unless ENV["HOOK_BITBUCKET"] == "0"
    post '/hooks/bitbucket' do
      hook_params = JSON.parse(request.body.read)

      if hook_params["ref"] == "refs/heads/master"
        puts("Received bitbucket hook for ref %s on repository %s" % [hook_params["commits"]["node"], hook_params["repository"]["absolute_url"]])
        "<pre>" + git_update_content + "</pre>"
      end
    end
  end

  unless ENV["HOOK_GOGS"] == "0"
    post '/hooks/gogs' do
      hook_params = JSON.parse(request.body.read)

      if hook_params["ref"] == "refs/heads/master"
        puts("Received gogs hook for ref %s on repository %s" % [hook_params["ref"], hook_params["repository"]["url"]])
        "<pre>" + git_update_content + "</pre>"
      end
    end
  end
end

get '/' do
  send_file(root_file)
end

get '/logout' do
  session[:uid] = nil
  "Logged out"
end

run Sinatra::Application
