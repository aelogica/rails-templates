# mocra.rb
# from Dr Nic Williams @ http://#{domain} + http://drnicwilliams.com
# 
# Optional:
#  TWITTER=1    - install + setup twitter_auth instead of restful_authentication
#  SKIP_GEMS=1  - don't install gems (useful if you know they are already installed)
#
# based on daring.rb from Peter Cooper

# Useful variables
  app_name       = File.basename(root)
  domain         = "mocra.com"
  app_url        = "#{app_name.gsub(/_/, '-')}.#{domain}"
  organization   = "Mocra"
  description    = ENV['DESCRIPTION'] || 'This is a cool app'
  no_downloading = ENV['NO_DOWNLOADING']
  skip_gems      = ENV['SKIP_GEMS']
  twitter_auth   = ENV['TWITTER']

def highline
  @highline ||= begin
    require "highline"
    HighLine.new
  end
end

def parse_keys(message)
  {
    :key    => (message.match(/Consumer key:\s+(.*)/)[1] rescue "TWITTER_CONSUMERKEY"),
    :secret => (message.match(/Consumer secret:\s+(.*)/)[1] rescue "TWITTER_CONSUMERSECRET")
  }
end

def template(&block)
  @store_template = block
end

def run_template
  @store_template.call
end

template do

# select slice + add CNAME

# github private repo + add self as collaborator if != github user

# cap: run 'ssh -o "StrictHostKeyChecking no" git@github.com'

# Delete unnecessary files
  run "rm README"
  run "rm public/index.html"
  run "rm public/favicon.ico"
  run "rm public/robots.txt"
  run "rm -f public/javascripts/*"
  run "rm -rf test"

# Download JQuery
unless no_downloading
  run "curl -L http://jqueryjs.googlecode.com/files/jquery-1.3.2.min.js > public/javascripts/jquery.js"
  run "curl -L http://jqueryjs.googlecode.com/svn/trunk/plugins/form/jquery.form.js > public/javascripts/jquery.form.js"
  run "curl -L http://plugins.jquery.com/files/jquery.template.js.txt > public/javascripts/jquery.template.js"
end
# Set up git repository
  git :init
  git :add => '.'
  
  file 'config/database.yml', <<-EOS.gsub(/^  /, '')
  development:
    adapter: mysql
    encoding: utf8
    reconnect: false
    database: #{app_name}_development
    pool: 5
    username: root
    password:
    socket: /tmp/mysql.sock

  test:
    adapter: mysql
    encoding: utf8
    reconnect: false
    database: #{app_name}_test
    pool: 5
    username: root
    password:
    socket: /tmp/mysql.sock

  production:
    adapter: mysql
    encoding: utf8
    reconnect: false
    database: #{app_name}_production
    pool: 5
    username: root
    password: 
  EOS
# Copy database.yml for distribution use
  run "cp config/database.yml config/database.yml.example"
  
# Set up .gitignore files
  run "touch tmp/.gitignore log/.gitignore vendor/.gitignore"
  run %{find . -type d -empty | grep -v "vendor" | grep -v ".git" | grep -v "tmp" | xargs -I xxx touch xxx/.gitignore}
  file '.gitignore', <<-EOS.gsub(/^  /, '')
  .DS_Store
  log/*.log
  tmp/**/*
  config/database.yml
  EOS

# Commit all work so far to the repository
  git :add => '.'
  git :commit => "-a -m 'Initial commit'"

# Set up session store initializer
  initializer 'session_store.rb', <<-END
ActionController::Base.session = { :session_key => '_#{(1..6).map { |x| (65 + rand(26)).chr }.join}_session', :secret => '#{(1..40).map { |x| (65 + rand(26)).chr }.join}' }
ActionController::Base.session_store = :active_record_store
  END

# Set up sessions
  rake 'db:drop:all'
  rake 'db:create:all'
  rake 'db:sessions:create'

# Install submoduled plugins
unless no_downloading
  plugin 'rspec', :git => 'git://github.com/dchelimsky/rspec.git', :submodule => true
  plugin 'rspec-rails', :git => 'git://github.com/dchelimsky/rspec-rails.git', :submodule => true
  plugin 'will_paginate', :git => 'git://github.com/mislav/will_paginate.git', :submodule => true
  plugin 'state_machine', :git => 'git://github.com/pluginaweek/state_machine.git', :submodule => true
  plugin 'quietbacktrace', :git => 'git://github.com/thoughtbot/quietbacktrace.git', :submodule => true
  plugin 'machinist', :git => 'git://github.com/notahat/machinist.git', :submodule => true
  plugin 'paperclip', :git => 'git://github.com/thoughtbot/paperclip.git', :submodule => true
  plugin 'email-spec', :git => 'git://github.com/drnic/email-spec.git', :submodule => true

# Install all gems
  gem 'sqlite3-ruby', :lib => 'sqlite3'
  if twitter_auth
    gem 'twitter-auth', :lib => 'twitter_auth'
  else                
    gem 'authenticated', 'User --include-activation --rspec'
  end

  rake 'gems:install', :sudo => true unless skip_gems


# Set up RSpec, user model, OpenID, etc, and run migrations
  generate "rspec"
  generate "cucumber"
  if twitter_auth
    generate "twitter_auth --oauth"
  else
    generate "authenticated", "user session"
  end
  generate 'app_layout' rescue nil

  generate "email_spec"
  
  append_file 'features/support/env.rb', <<-EOS.gsub(/^  /, '')
  require "email_spec/cucumber"
  require File.dirname(__FILE__) + "/../../spec/blueprints"
  EOS
end
  
  generate 'controller', 'home index'
  generate 'controller', 'protected index'

  file 'app/controllers/protected_controller.rb', <<-EOS.gsub(/^  /, '')
  class ProtectedController < ApplicationController
    before_filter :login_required

    def index
    end

  end
  EOS

  if twitter_auth
    file 'app/views/home/index.html.erb', <<-EOS.gsub(/^    /, '')
    <%= link_to "Protected", :controller => :protected %>

    <h3>Recent users (<%= User.count %>)</h3>
    <ul>
    <% for user in User.all -%>
      <li><%= image_tag(user.profile_image_url) %><%= user.name %> (<%= link_to h(user.login), "http://twitter.com/\#{h user.login}" %>)</li>
    <% end -%>
    </ul>
    EOS
  else
    file 'app/views/home/index.html.erb', '<%= link_to "Protected Area", :controller => :protected %>'
  end
  file 'app/views/protected/index.html.erb', '<h3><%= current_user.login %></h3>'
  
  if twitter_auth
    # Twitter app registation

    # requires: 
    # * sudo gem install twitter (need drnic version with register_oauth command)
    # * twitter install
    # * twitter add
    twitter_users = `twitter list | grep "^[* ] " | sed -e "s/[* ] //"`.split
    twitter_user = highline.choose(*twitter_users) do |menu|
      menu.prompt = "Which twitter user?  "
    end
    message = run "twitter register_oauth #{twitter_user} '#{app_name}' http://#{app_url} '#{description}' organization='#{organization}' organization_url=http://#{domain}"
    twitter_auth_keys = parse_keys(message)

    append_file 'config/environments/development.rb', "\n\nOpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE\n"
    append_file 'config/environments/test.rb', "\n\nOpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE\n"
    
    file 'config/twitter_auth.yml', <<-EOS.gsub(/^    /, '')
    development:
      strategy: oauth
      oauth_consumer_key: #{twitter_auth_keys[:key]}
      oauth_consumer_secret: #{twitter_auth_keys[:secret]}
      base_url: "https://twitter.com"
      api_timeout: 10
      remember_for: 14 # days
      oauth_callback: "http://#{app_name}.local/oauth_callback"
    test:
      strategy: oauth
      oauth_consumer_key: #{twitter_auth_keys[:key]}
      oauth_consumer_secret: #{twitter_auth_keys[:secret]}
      base_url: "https://twitter.com"
      api_timeout: 10
      remember_for: 14 # days
      oauth_callback: "http://#{app_name}.local/oauth_callback"
    production:
      strategy: oauth
      oauth_consumer_key: #{twitter_auth_keys[:key]}
      oauth_consumer_secret: #{twitter_auth_keys[:secret]}
      base_url: "https://twitter.com"
      api_timeout: 10
      remember_for: 14 # days
      oauth_callback: "http://#{app_url}/oauth_callback"
    EOS
  end
  
  file 'spec/blueprints.rb', ''

  rake 'db:migrate'
  rake 'db:test:clone'

# Routes
  if twitter_auth
    route "map.login  '/login',  :controller => 'session', :action => 'new'"
    route "map.session_create  '/sessions/create',  :controller => 'session', :action => 'create'"
    route "map.session_destroy  '/sessions/destroy',  :controller => 'session', :action => 'destroy'"
    route "map.oauth_callback  '/oauth_callback',  :controller => 'session', :action => 'oauth_callback'"
    
  else
    route "map.signup  '/signup', :controller => 'users',   :action => 'new'"
    route "map.login  '/login',  :controller => 'session', :action => 'new'"
    route "map.logout '/logout', :controller => 'session', :action => 'destroy'"
    route "map.activate '/activate/:activation_code', :controller => 'users', :action => 'activate', :activation_code => nil"
  end
  
  route "map.root :controller => 'home', :action => 'index'"
  
# Deployment
  capify!

  file 'config/deploy.rb', <<-EOS.gsub(/^  /, '')
  # REMEMBER:
  # Create github private project
  #  $ git remote add origin git@github.com:mocra/#{app_name}.git
  #  $ git push origin master
  #
  # After you can log into remote machine (cap deploy:setup)
  #  $ ssh #{app_url} -A
  #  # ssh git@github.com
  #  => 'yes'
  #  Hi drnic! You've successfully authenticated, but GitHub does not provide shell access.
  #
  
  require 'deprec'

  set :application, "#{app_name}"
  set :domain,      "\#{application}.#{domain}"
  set :repository,  "git@github.com:mocra/\#{application}.git"

  # If you aren't using Subversion to manage your source code, specify
  # your SCM below:
  set :scm, :git
  set :ruby_vm_type,      :ree        # :ree, :mri
  set :web_server_type,   :apache     # :apache, :nginx
  set :app_server_type,   :passenger  # :passenger, :mongrel
  set :db_server_type,    :mysql      # :mysql, :postgresql, :sqlite

  ssh_options[:forward_agent] = true
  # set :packages_for_project, %w(libmagick9-dev imagemagick libfreeimage3) # list of packages to be installed
  # set :gems_for_project, %w() # list of gems to be installed

  # Update these if you're not running everything on one host.
  role :app, domain
  role :web, domain

  # If you aren't deploying to /opt/apps/\#{application} on the target
  # servers (which is the deprec default), you can specify the actual location
  # via the :deploy_to variable:
  set :deploy_to, "/opt/apps/\#{application}"

  before 'deploy:cold', 'deploy:upload_database_yml'
  after 'deploy:symlink', 'deploy:create_symlinks'

  namespace :deploy do
    task :restart, :roles => :app, :except => { :no_release => true } do
      top.deprec.app.restart
    end

    desc "Uploads database.yml file to shared path"
    task :upload_database_yml, :roles => :app do
      put(File.read('config/database.yml'), "\#{shared_path}/config/database.yml", :mode => 0644)
    end

    desc "Symlinks database.yml file from shared folder"
    task :create_symlinks, :roles => :app do
      run "rm -f \#{current_path}/config/database.yml"
      run "ln -s \#{shared_path}/config/database.yml \#{current_path}/config/database.yml"
    end
  end
  EOS


# Initialize submodules
  git :submodule => "init"

# Commit all work so far to the repository
  git :add => '.'
  git :commit => "-a -m 'Plugins and config'"

# Setup slicehost slice

  slices = slices_name_and_ip
  slice_name = highline.choose(slices.keys.sort) do |menu|
    menu.prompt = "Install application on which slice?  "
  end
  run "slicehost-dns add_cname #{domain} #{app_name} #{slice_name}"

  if twitter_auth
    log "The next step is to edit config/twitter_auth.yml to reflect our OAuth client key and secret (to register your application log in to Twitter and visit http://twitter.com/oauth_clients)."
    # `open http://intridea.com/2009/3/23/twitter-auth-for-near-instant-twitter-apps`
    # `open http://#{app_url}`
  end
  
# Success!
  log "SUCCESS!"

end

run_template unless ENV['TEST_MODE'] # hold off running the template whilst in unit testing mode