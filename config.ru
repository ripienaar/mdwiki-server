#!/usr/bin/ruby

require 'sinatra'
require 'filelock'
require 'sinatra-index'
require 'json'

register Sinatra::Index

configure do
  if ENV["WIKI_ROOT"]
    set :public_folder, ENV["WIKI_ROOT"]
  else
    set :public_folder, Proc.new { File.join(root, "wiki") }
  end

  use_static_index 'index.html'
end

helpers do
  def root_file
    ENV["ROOT_FILE"] || "mdwiki.html"
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

run Sinatra::Application
