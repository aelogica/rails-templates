# mocra.rb
# from Dr Nic Williams @ http://#{domain} + http://drnicwilliams.com
# 
# Optional:
#  DOMAIN       - parent domain (default: mocra.com)
#  SKIP_GEMS=1  - don't install gems (useful if you know they are already installed)
#
#  The following are just for twitter oauth registration:
#  ORGANIZATION - name of your company (default: Mocra)
#  DESCRIPTION  - description of your app (default: This is a cool app)
#
# Required gems for this template:
#   gem install highline
#   gem install deprec
#   gem install defunkt-github --source http://gems.github.com
#   gem install uhlenbrock-slicehost-tools --source=http://gems.github.com
#   gem install drnic-twitter --source=http://gems.github.com
#
# Some setup steps (if wanting twitter_auth support)
#  twitter install
#  twitter add
#  -> enter username + password; repeat if you have multiple twitter accounts

# wrap template commands in block so their execution can be controlled
# in unit testing
def template(&block)
  @store_template = block
end

template do
  app_name       = File.basename(root)
  application    = app_name.gsub(/[_-]/, ' ').titleize
  app_subdomain  = app_name.gsub(/[_\s]/, '-').downcase
  app_db         = app_name.gsub(/[-\s]/, '_').downcase
  domain         = ENV['DOMAIN'] || 'mocra.com'
  app_url        = "#{app_subdomain}.#{domain}"
  organization   = ENV['ORGANIZATION'] || "Mocra"
  description    = ENV['DESCRIPTION'] || 'This is a cool app'
  skip_gems      = ENV['SKIP_GEMS']

  github_user = run("git config --get github.user").strip
  if github_user.blank?
    puts <<-EOS.gsub(/^    /, '')
    You need to install your github username and API token.
    
    * Go to http://github.com/accounts
    * Click "Global Git Config"
    * Execute the two lines displayed
    * Run "git config --list" to check that github.user and github.token are installed
    EOS
    exit
  end
  
# Authentication selection
  auth = highline.choose(*%w[none restful_authentication twitter_auth]) do |menu|
    menu.prompt = "Which user authentication system?  "
  end
  authentication         = auth != "none"
  twitter_auth           = auth == "twitter_auth"
  restful_authentication = auth == "restful_authentication"

# Setup slicehost slice

  slice_name = highline.choose(*slice_names) do |menu|
    menu.prompt = "Install http://#{app_url} application on which slice?  "
  end
  run "slicehost-dns add_cname #{domain} #{app_subdomain} #{slice_name}"

# Setup twitter oauth on twitter.com
  if twitter_auth
    twitter_users = `twitter list | grep "^[* ] " | sed -e "s/[* ] //"`.split
    if twitter_users.size > 1
      twitter_user = highline.choose(*twitter_users) { |menu| menu.prompt = "Which twitter user?  " }
    else
      twitter_user = twitter_users.first
    end
    twitter_permission = highline.choose("read-only", "read-write") do |menu|
      menu.prompt = "What access level does the application need to user's twitter accounts?  "
    end
    twitter_readwrite_flag = (twitter_permission == 'read-write') ? ' --readwrite' : ''

    message = run "twitter register_oauth #{twitter_user} '#{application}' http://#{app_url} '#{description}' organization='#{organization}' organization_url=http://#{domain}#{twitter_readwrite_flag}"
    twitter_auth_keys = parse_keys(message)
  end

# Public/private github repo
  repo_privacy = highline.choose('public', 'private') { |menu| menu.prompt = "Public/private github repo?  " }
  is_private_github = repo_privacy == 'private'
  
# Authentication gems/plugins

if twitter_auth
  plugin 'twitter_auth', :git => 'git://github.com/mbleigh/twitter-auth.git', :submodule => true
elsif restful_authentication
  plugin 'restful_authentication', :git => 'git://github.com/technoweenie/restful-authentication.git', :submodule => true
end

# Delete unnecessary files
  run "rm README"
  run "rm public/index.html"
  run "rm public/favicon.ico"
  run "rm public/robots.txt"
  run "rm -f public/javascripts/*"
  run "rm -rf test"

  file "README.md", ""

# Download JQuery
# TODO move these to app_layout + update application.html.erb
  run "curl -L -# http://jqueryjs.googlecode.com/files/jquery-1.3.2.min.js > public/javascripts/jquery.js"
  run "curl -L -# http://jqueryjs.googlecode.com/svn/trunk/plugins/form/jquery.form.js > public/javascripts/jquery.form.js"
  run "curl -L -# http://plugins.jquery.com/files/jquery.template.js.txt > public/javascripts/jquery.template.js"

  
  file 'config/database.yml', <<-EOS.gsub(/^  /, '')
  development:
    adapter: mysql
    encoding: utf8
    reconnect: false
    database: #{app_db}_development
    pool: 5
    username: root
    password:
    socket: /tmp/mysql.sock

  test:
    adapter: mysql
    encoding: utf8
    reconnect: false
    database: #{app_db}_test
    pool: 5
    username: root
    password:
    socket: /tmp/mysql.sock

  production:
    adapter: mysql
    encoding: utf8
    reconnect: false
    database: #{app_db}_production
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
  config/initializers/site_keys.rb
  EOS

# Set up git repository and commit all work so far to the repository
  git :init
  git :add => '.'
  git :commit => "-a -m 'Initial commit'"

# Set up session store initializer
  initializer 'session_store.rb', <<-EOS.gsub(/^  /, '')
  ActionController::Base.session = { :session_key => '_#{(1..6).map { |x| (65 + rand(26)).chr }.join}_session', :secret => '#{(1..40).map { |x| (65 + rand(26)).chr }.join}' }
  ActionController::Base.session_store = :active_record_store
  EOS

# Set up sessions
  rake 'db:create:all'
  rake 'db:sessions:create'

# Install submoduled plugins
  plugin 'will_paginate', :git => 'git://github.com/mislav/will_paginate.git', :submodule => true
  plugin 'state_machine', :git => 'git://github.com/pluginaweek/state_machine.git', :submodule => true
  plugin 'rails_footnotes', :git => 'git://github.com/josevalim/rails-footnotes.git', :submodule => true
  plugin 'machinist', :git => 'git://github.com/notahat/machinist.git', :submodule => true
  plugin 'paperclip', :git => 'git://github.com/thoughtbot/paperclip.git', :submodule => true
  plugin 'cucumber', :git => 'git://github.com/aslakhellesoy/cucumber.git', :submodule => true
  plugin 'email-spec', :git => 'git://github.com/drnic/email-spec.git', :submodule => true
  plugin 'rspec', :git => 'git://github.com/dchelimsky/rspec.git', :submodule => true
  plugin 'rspec-rails', :git => 'git://github.com/dchelimsky/rspec-rails.git', :submodule => true

# Set up RSpec, user model, OpenID, etc, and run migrations
  generate "rspec"
  generate "cucumber"
  generate "email_spec"
  
  if twitter_auth
    generate "twitter_auth --oauth"
  elsif restful_authentication
    generate 'authenticated', 'user session --include-activation --rspec'
  end
  generate 'app_layout' rescue nil

  append_file 'features/support/env.rb', <<-EOS.gsub(/^  /, '')
  require "email_spec/cucumber"
  require File.dirname(__FILE__) + "/../../spec/blueprints"

  Before do
    FakeWeb.allow_net_connect = false
  end
  EOS

  append_file 'spec/spec_helper.rb', <<-EOS.gsub(/^  /, '')
  require File.dirname(__FILE__) + '/blueprints'
  EOS
  
  append_file 'config/environments/test.rb', <<-EOS.gsub(/^  /, '')
  config.gem 'fakeweb', :version => '>= 1.2.0'
  config.gem 'faker', :version => '>= 0.3.1'
  EOS
  
  file 'spec/blueprints.rb', <<-EOS.gsub(/^  /, '')
  # Use 'Ruby Machinst.tmbundle' Cmd+B to generate blueprints from class names
  require "faker"

  Sham.name  { Faker::Name.name }
  Sham.login { Faker::Internet.user_name.gsub(/\W/, '')[0..14] } # max 15 chars
  Sham.message { Faker::Lorem.sentence }
  
  EOS

  generate 'rspec_controller', 'home index'
  
  if authentication
    generate 'rspec_controller', 'protected index'

    file 'app/controllers/protected_controller.rb', <<-EOS.gsub(/^  /, '')
    class ProtectedController < ApplicationController
      before_filter :login_required

      def index
      end

    end
    EOS

    file 'app/views/protected/index.html.erb', '<h3><%= current_user.login %></h3>'
  end
  
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
  
  if twitter_auth
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
      oauth_callback: "http://#{app_subdomain}.local/oauth_callback"
    test:
      strategy: oauth
      oauth_consumer_key: #{twitter_auth_keys[:key]}
      oauth_consumer_secret: #{twitter_auth_keys[:secret]}
      base_url: "https://twitter.com"
      api_timeout: 10
      remember_for: 14 # days
      oauth_callback: "http://#{app_subdomain}.local/oauth_callback"
    production:
      strategy: oauth
      oauth_consumer_key: #{twitter_auth_keys[:key]}
      oauth_consumer_secret: #{twitter_auth_keys[:secret]}
      base_url: "https://twitter.com"
      api_timeout: 10
      remember_for: 14 # days
      oauth_callback: "http://#{app_url}/oauth_callback"
    EOS
  elsif restful_authentication
    environment("config.active_record.observers = :user_observer")
    initializer("mailer.rb", <<-EOS.gsub(/^    /, ''))
    mailer_options = YAML.load_file("\#{RAILS_ROOT}/config/mailer.yml")
    ActionMailer::Base.smtp_settings = mailer_options
    EOS
    file("config/mailer.yml", <<-EOS.gsub(/^    /, ''))
    :address: mail.authsmtp.com
    :domain: #{domain}
    :authentication: :login
    :user_name: USERNAME
    :password: PASSWORD
    EOS
    append_file("app/views/users/new.html.erb", <<-EOS.gsub(/^    /, ''))
    <h2>FIRST - setup activation config/mailer.yml for your mail server</h2>
    EOS
    gsub_file("app/controllers/application_controller.rb", /class ApplicationController < ActionController::Base/mi) do
      "class ApplicationController < ActionController::Base\n  include AuthenticatedSystem"
    end
  end
  
  rake 'db:migrate'
  rake 'db:test:clone'

# Routes
  if twitter_auth
    route "map.login  '/login',  :controller => 'session', :action => 'new'"
    route "map.session_create  '/sessions/create',  :controller => 'session', :action => 'create'"
    route "map.session_destroy  '/sessions/destroy',  :controller => 'session', :action => 'destroy'"
    route "map.oauth_callback  '/oauth_callback',  :controller => 'session', :action => 'oauth_callback'"
    
  elsif restful_authentication
    # restful-authentication seems to create other routes but not this one
    route "map.activate '/activate/:activation_code', :controller => 'users', :action => 'activate', :activation_code => nil"
  end
  
  route "map.root :controller => 'home', :action => 'index'"
  
# Deployment
  capify!
  
  repository = "git#{ is_private_github ? '@' : '://' }github.com#{ is_private_github ? ':' : '/' }#{github_user}/\#{application}.git"

  file 'config/deploy.rb', <<-EOS.gsub(/^  /, '')
  require 'deprec'

  set :application, "#{app_name}"
  set :domain,      "#{app_subdomain}.#{domain}"
  set :repository,  "#{repository}"
  
  set :scm, :git
  set :git_enable_submodules, 1
  
  set :ruby_vm_type,      :ree        # :ree, :mri
  set :web_server_type,   :apache     # :apache, :nginx
  set :app_server_type,   :passenger  # :passenger, :mongrel
  set :db_server_type,    :mysql      # :mysql, :postgresql, :sqlite

  set(:mysql_admin_pass) { db_password }

  ssh_options[:forward_agent] = true
  # set :packages_for_project, %w(libmagick9-dev imagemagick libfreeimage3) # list of packages to be installed
  # set :gems_for_project, %w() # list of gems to be installed

  # Update these if you're not running everything on one host.
  role :app, domain
  role :web, domain
  role :db, domain, :primary => true

  # If you aren't deploying to /opt/apps/\#{application} on the target
  # servers (which is the deprec default), you can specify the actual location
  # via the :deploy_to variable:
  set :deploy_to, "/opt/apps/\#{application}"

  before 'deploy:cold', 'deploy:upload_database_yml'
  before 'deploy:cold', 'deploy:ping_ssh_github'
  after 'deploy:symlink', 'deploy:create_symlinks'

  namespace :deploy do
    task :restart, :roles => :app, :except => { :no_release => true } do
      top.deprec.app.restart
    end

    task :start, :roles => :app, :except => { :no_release => true } do
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

    desc "ssh git@github.com"
    task :ping_ssh_github do
      run 'ssh -o "StrictHostKeyChecking no" git@github.com || true'
    end
  end
  EOS


# Initialize submodules
  git :submodule => "init"

# Commit all work so far to the repository
  git :add => '.'
  git :commit => "-a -m 'Plugins and config'"

# GitHub project creation
  run "github create-from-local#{ ' --private' if is_private_github }"

# Deploy!

  run "cap deploy:setup"
  run "cap deploy:cold"

  git :add => '.'
  git :commit => "-a -m 'Deprec config'"
  git :push => 'origin master'

# Success!
  log "SUCCESS! Your app is running at http://#{app_url}"

end

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

def run_template
  @store_template.call
end

def slice_names
  slicehost_list = run "slicehost-slice list"
  slicehost_list.split("\n").map { |name_ip| name_ip.match(/\+\s+([^\s]+)\s/)[1] }
end

run_template unless ENV['TEST_MODE'] # hold off running the template whilst in unit testing mode