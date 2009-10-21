# mocra.rb
# from Dr Nic Williams @ http://mocra.com + http://drnicwilliams.com
# 
# Optional:
#  DOMAIN       - parent domain (default: mocra.com)
#  SKIP_GEMS=1  - don't install gems (useful if you know they are already installed)
#  DB=mysql     - else sqlite3 by default
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
  domain         = 'heroku.com'
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

# Delete unnecessary files
  run "rm README"
  run "rm public/index.html"
  run "rm public/favicon.ico"
  run "rm -f public/javascripts/*"
  run "rm -rf test"

  file "README.md", ""
  
  file "public/robots.txt", <<-EOS.gsub(/^  /, '')
  User-agent: *
  Disallow: /
  EOS
  
  if ENV['DB'] == "mysql"
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
  end
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
  db/*.sqlite3
  EOS

# Set up git repository and commit all work so far to the repository
  git :init
  git :add => '.'
  git :commit => "-a -m 'Initial commit'"

# Authentication gems/plugins

if twitter_auth
  plugin 'twitter_auth', :git => 'git://github.com/mbleigh/twitter-auth.git'
elsif restful_authentication
  plugin 'restful_authentication', :git => 'git://github.com/technoweenie/restful-authentication.git'
end


# Set up session store initializer
  initializer 'session_store.rb', <<-EOS.gsub(/^  /, '')
  ActionController::Base.session = { :session_key => '_#{(1..6).map { |x| (65 + rand(26)).chr }.join}_session', :secret => '#{(1..40).map { |x| (65 + rand(26)).chr }.join}' }
  ActionController::Base.session_store = :active_record_store
  EOS

# Set up sessions
  rake 'db:create:all'
  rake 'db:sessions:create'

# Common gems/plugins

  heroku_gem "giraffesoft-resource_controller", :lib => "resource_controller", :source => "http://gems.github.com"
  heroku_gem 'mislav-will_paginate', :source => 'http://gems.github.com', :lib => 'will_paginate'
  heroku_gem 'pluginaweek-state_machine', :source => 'http://gems.github.com', :lib => 'state_machine'
  heroku_gem 'justinfrench-formtastic', :source => 'http://gems.github.com', :lib => 'formtastic'
  heroku_gem "haml", :version => ">= 2.0.0"
  
  plugin 'validation_reflection', :git => 'git://github.com/redinger/validation_reflection.git'

# Gems - testing
  gem_with_version "webrat",      :lib => false, :env => 'test'
  gem_with_version "rspec",       :lib => false, :env => 'test'
  gem_with_version "rspec-rails", :lib => 'spec/rails', :env => 'test'
  gem_with_version 'bmabey-email_spec', :source => 'http://gems.github.com', :lib => 'email_spec', :env => 'test'
  gem_with_version 'notahat-machinist', :source => 'http://gems.github.com', :lib => 'machinist', :env => 'test'
  gem_with_version 'fakeweb', :env => 'test'
  gem_with_version 'faker', :env => 'test'
  
# Make sure all these gems are actually installed locally
  run "sudo rake gems:install RAILS_ENV=test" unless skip_gems

  generate "rspec"
  generate "email_spec"

# Gems - cucumber
  generate "cucumber"
  
  remove_gems :env => 'cucumber'
  gem_with_version "cucumber", :lib => false, :env => 'cucumber'
  gem_with_version "webrat",      :lib => false, :env => 'cucumber'
  gem_with_version "rspec",       :lib => false, :env => 'cucumber'
  gem_with_version "rspec-rails", :lib => 'spec/rails', :env => 'cucumber'
  gem_with_version 'bmabey-email_spec', :source => 'http://gems.github.com', :lib => 'email_spec', :env => 'cucumber'
  gem_with_version 'notahat-machinist', :source => 'http://gems.github.com', :lib => 'machinist', :env => 'cucumber'
  gem_with_version 'fakeweb', :env => 'cucumber'
  gem_with_version 'faker', :env => 'cucumber'

# Make sure all these gems are actually installed locally
  run "sudo rake gems:install RAILS_ENV=cucumber" unless skip_gems

# Install plugins
  plugin 'blue_ridge', :git => 'git://github.com/drnic/blue-ridge.git'

# Hook for layouts, assets
  generate 'app_layout'

# Set up RSpec, user model, OpenID, etc, and run migrations
  run "haml --rails ."
  run "rm -rf vendor/plugins/haml" # use gem install
  generate "blue_ridge"
  
  if twitter_auth
    heroku_gem 'ezcrypto'
    heroku_gem 'oauth'
    generate 'twitter_auth', '--oauth'
  elsif restful_authentication
    generate 'authenticated', 'user session --include-activation --rspec'
  end
  
  file 'public/stylesheets/form.css', <<-CSS.gsub(/^  /, '')
  /* Decent styling of formtastic forms */
  form fieldset {
    border: 0;
  }

  form li {
    list-style-type: none;
  }

  form li {
    margin: 0 0 0.5em;
    clear: both;
  }

  form label {
    display: block;
    text-align: right;
    width: 150px;
    float: left;
    position: relative;
    top: 6px;
    padding-right: 6px;
  }

  form .inline-errors {
    display: inline;
    color: red;
  }
  CSS
  
  append_file 'features/support/env.rb', <<-EOS.gsub(/^  /, '')
  require "email_spec/cucumber"
  require File.dirname(__FILE__) + "/../../spec/blueprints"

  Before do
    FakeWeb.allow_net_connect = false
  end
  EOS

  append_file 'spec/spec_helper.rb', <<-EOS.gsub(/^  /, '')
  require File.dirname(__FILE__) + '/blueprints'
  
  # When running specs in TextMate, provide an rputs method to cleanly print objects into HTML display
  # From http://talklikeaduck.denhaven2.com/2009/09/23/rspec-textmate-pro-tip
  module Kernel
    if ENV.keys.find {|env_var| env_var.start_with?("TM_")}
      def rputs(*args)
        puts( *["<pre>", args.collect {|a| CGI.escapeHTML(a.to_s)}, "</pre>"])
      end
    else
      alias_method :rputs, :puts
    end
  end
  EOS
  
  file 'spec/blueprints.rb', <<-EOS.gsub(/^  /, '')
  # Use 'Ruby Machinst.tmbundle' Cmd+B to generate blueprints from class names
  require 'machinist/active_record'
  require 'sham'
  require 'faker'

  Sham.define do
    name              { Faker::Name.name }
    first_name        { Faker::Name.first_name }
    last_name         { Faker::Name.last_name }
    company_name      { Faker::Company.name }
    login             { Faker::Internet.user_name.gsub(/\W/, '')[0..14] } # max 15 chars
    message           { Faker::Lorem.sentence }
    description       { Faker::Lorem.sentence }
    email             { Faker::Internet.email }
  end
  
  Dir[File.join(File.dirname(__FILE__), 'blueprints', '*_blueprint.rb')].each {|bp| require bp}
  EOS

# Initial controllers/views
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

    file 'app/views/protected/index.html.haml', '%h3= current_user.login'
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
    file 'app/views/home/index.html.haml', '%h1 Welcome!'
  end
  
# Miscellaneous configuration
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

# Run migrations
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
  
# Commit all work so far to the repository
  git :add => '.'
  git :commit => "-a -m 'Gems, plugins and config'"

  # Deploy!
  if highline.agree "Deploy to Heroku now?  "
    heroku :create, app_subdomain
    git :push => "heroku master"
    heroku :rake, "db:migrate"
    heroku :open

    # Success!
    log "SUCCESS! Your app is running at http://#{app_url}"
  end

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

def heroku(cmd, arguments="")
  run "heroku #{cmd} #{arguments}"
end

def gem_with_version(name, options = {})
  if gem_spec = Gem.source_index.find_name(name).last
    version = gem_spec.version.to_s
    options = {:version => ">= #{version}"}.merge(options)
    gem(name, options)
  else
    $stderr.puts "ERROR: cannot find gem #{name}; cannot load version. Adding it anyway."
    gem(name, options)
  end
  options
end

def remove_gems(options)
  env = options.delete(:env)
  gems_code = /^\s*config.gem.*\n/
  file = env.nil? ? 'config/environment.rb' : "config/environments/#{env}.rb"
  gsub_file file, gems_code, ""
end

# Usage:
#   heroku_gem 'oauth'
#   heroku_gem 'hpricot', :version => '>= 0.2', :source => 'code.whytheluckystiff.net'
#   heroku_gem 'dm-core', :version => '0.9.10'
def heroku_gem(gem, options = {})
  options = gem_with_version(gem, options)
  file ".gems", "" unless File.exists?(".gems")

  version_str = options[:version] ? "--version '#{options[:version]}'" : ""
  source_str  = options[:source]  ? "--source '#{options[:source]}'" : ""
  append_file '.gems', "#{gem} #{version_str} #{source_str}\n"
end

def run_template
  @store_template.call
end

def plugin *args
  
end

run_template unless ENV['TEST_MODE'] # hold off running the template whilst in unit testing mode
