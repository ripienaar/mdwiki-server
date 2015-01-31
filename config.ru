#!/usr/bin/ruby

require 'sinatra'
require 'omniauth-auth0'

configure do
  if ENV["WIKI_ROOT"]
    set :public_folder, ENV["WIKI_ROOT"]
  else
    set :public_folder, Proc.new { File.join(root, "wiki") }
  end

  unless ENV["LOCAL_DEV"] == "1"
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
  def unlock(lockfile)
    File.unlink(lockfile)
  end

  def lock(lockfile)
    if File.exist?(lockfile)
      locking_pid = File.readlines(lockfile).first.chomp

      if File.directory?("/proc/%s" % locking_pid)
        raise("Another checkout is running with pid %s. Remove %s if no other copy is running" % [locking_pid, lockfile])
      else
        unlock(lockfile)
      end
    end

    File.open(lockfile, "w") {|f| f.puts $$}

    true
  end

  def with_lock(lockfile)
    lock_owner = lock(lockfile)

    yield
  rescue
    raise
  ensure
    unlock(lockfile) if lock_owner
  end

  def current_user
    ENV["LOCAL_DEV"] == "1" || !session[:uid].nil?
  end

  def git_update_content
    Dir.chdir(settings.public_folder) do
      `git pull origin master 2>&1`
    end
  end
end

before do
  pass if request.path_info =~ /^\/auth\//
  pass if request.path_info =~ /^\/update_hook\/$/

  redirect to('/auth/auth0') unless current_user
end

get '/update_hook/simple' do
  with_lock("/tmp/update_hook") do
    "<pre>" + git_update_content + "</pre>"
  end
end

get '/auth/auth0/callback' do
  session[:uid] = env['omniauth.auth']['uid']
  redirect to('/')
end

get '/auth/failure' do
  "Authentication failed"
end

get '/' do
  File.read("mdwiki.html")
end

run Sinatra::Application
