#!/usr/bin/ruby

require 'sinatra'
require 'omniauth-auth0'
require 'filelock'
require 'sinatra-index'

register Sinatra::Index

configure do
  if ENV["WIKI_ROOT"]
    set :public_folder, ENV["WIKI_ROOT"]
  else
    set :public_folder, Proc.new { File.join(root, "wiki") }
  end

  use_static_index 'index.html'

  unless ENV["LOCAL_DEV"] == "1" || ENV["NO_AUTH"] == "1"
    ["SESSION_SECRET", "AUTH0_CLIENT_ID", "AUTH0_CLIENT_SECRET", "AUTH0_DOMAIN"].each do |v|
      next if ENV.include?(v)

      raise("%s needs to be set in the environment for this app to function" % v)
    end

    use Rack::Session::Cookie, :key => 'rack.session',
                               :expire_after => 86400,
                               :secret => ENV["SESSION_SECRET"]

    use OmniAuth::Builder do
      provider :auth0,
               ENV["AUTH0_CLIENT_ID"],
               ENV["AUTH0_CLIENT_SECRET"],
               ENV["AUTH0_DOMAIN"],
               callback_path: "/auth/auth0/callback"
    end
  end
end

helpers do
  def root_file
    ENV["ROOT_FILE"] || "mdwiki.html"
  end

  def current_user
    ENV["LOCAL_DEV"] == "1" || !session[:uid].nil?
  end

  def git_update_content
    Filelock("/tmp/update_hook") do
      Dir.chdir(settings.public_folder) do
        `git pull origin master 2>&1`

        if File.exist?("post-hook.sh") && File.executable?("post-hook.sh")
          `./post-hook.sh`
        end
      end
    end
  end
end

before do
  pass if request.path_info =~ /^\/auth\//
  pass if request.path_info =~ /^\/hooks\//

  redirect to('/auth/auth0') unless current_user
end

get '/auth/auth0/callback' do
  session[:uid] = env['omniauth.auth']['uid']
  redirect to('/')
end

get '/auth/failure' do
  "Authentication failed"
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
