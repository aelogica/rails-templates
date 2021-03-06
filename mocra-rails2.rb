# mocra.rb
# from Dr Nic Williams @ http://mocra.com + http://drnicwilliams.com
# 
# Optional:
#  DOMAIN       - parent domain (default: mocra.com)
#  INSTALL_GEMS=1  - don't install gems (useful if you know they are already installed)
#  DB=mysql     - else sqlite3 by default
#  NO_SUDO=1    - don't use sudo to install gems
#  HEROKU=1     - create heroku app, else will be prompted
#  NO_PLUGINS=1    - for testing script, don't install plugins (which are slow)
#  NO_APP_LAYOUT=1 - don't install new theme/run app_layout generator
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

load File.join(File.dirname(root), File.dirname(template), "template_helpers.rb")

template do
  application    = app_name.gsub(/[_-]/, ' ').titleize
  app_subdomain  = app_name.gsub(/[_\s]/, '-').downcase
  app_db         = app_name.gsub(/[-\s]/, '_').downcase
  domain         = 'heroku.com'
  app_url        = "#{app_subdomain}.#{domain}"
  organization   = ENV['ORGANIZATION'] || "Mocra"
  description    = ENV['DESCRIPTION'] || 'This is a cool app'
  install_gems   = ENV['INSTALL_GEMS']
  sudo           = ENV['NO_SUDO'] ? '' : 'sudo '

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
  
# Delete unnecessary files
  run "rm README"
  run "rm public/index.html"
  run "rm public/favicon.ico"
  run "rm -f public/javascripts/*"
  run "rm -rf test"

  file "README.md", ""
  
  file "public/robots.txt", <<-EOS.gsub(/^    /, '')
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
  
# Set up .gitignore files
  run "touch tmp/.gitignore log/.gitignore vendor/.gitignore"
  run %{find . -type d -empty | grep -v "vendor" | grep -v ".git" | grep -v "tmp" | xargs -I xxx touch xxx/.gitignore}
  file '.gitignore', <<-EOS.gsub(/^    /, '')
    .DS_Store
    log/*.log
    tmp/*
    tmp/**/*
    capybara-*.html
    config/database.yml
    config/initializers/site_keys.rb
    db/*.sqlite3
    rerun.txt
  EOS
  
  file 'lib/tasks/cron.rake', <<-EOS.gsub(/^    /, '')
    desc "Entry point for cron tasks"
    task :cron do

    end
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

# Common gems/plugins

  heroku_gem "inherited_resources", :version => '1.0.6' # last rails-2.3 version of the gem
  heroku_gem 'will_paginate'
  heroku_gem 'formtastic'
  heroku_gem 'haml', :version => ">= 2.0.0"
  # Not sure if we need this: heroku_gem 'exceptional'
  
  plugin 'validation_reflection', :git => 'git://github.com/redinger/validation_reflection.git'

# Gems - testing
  gem_with_version "capybara",      :lib => false, :env => 'test'
  gem_with_version "rspec",       :lib => false, :env => 'test'
  gem_with_version "rspec-rails", :lib => 'spec/rails', :env => 'test'
  gem_with_version 'email_spec', :env => 'test'
  gem_with_version 'machinist', :env => 'test'
  gem_with_version 'fakeweb', :env => 'test'
  gem_with_version 'faker', :env => 'test'
  
# Make sure all these gems are actually installed locally
  run "#{sudo}rake gems:install RAILS_ENV=test" if install_gems

  generate "rspec"
  generate "email_spec"

# Gems - cucumber
  generate "cucumber", "--capybara"
  
  remove_gems :env => 'cucumber'
  gem_with_version "cucumber", :lib => false, :env => 'cucumber'
  gem_with_version "capybara",      :lib => false, :env => 'cucumber'
  gem_with_version "rspec",       :lib => false, :env => 'cucumber'
  gem_with_version "rspec-rails", :lib => 'spec/rails', :env => 'cucumber'
  gem_with_version 'email_spec', :env => 'cucumber'
  gem_with_version 'machinist', :env => 'cucumber'
  gem_with_version 'fakeweb', :env => 'cucumber'
  gem_with_version 'faker', :env => 'cucumber'

# Make sure all these gems are actually installed locally
  run "#{sudo}rake gems:install RAILS_ENV=cucumber" if install_gems

# Hook for layouts, assets
  generate 'app_layout' unless ENV['NO_APP_LAYOUT']

# Set up RSpec, user model, OpenID, etc, and run migrations
  run "haml --rails ."
  run "rm -rf vendor/plugins/haml" # use gem install
  
  file 'public/stylesheets/form.css', <<-CSS.gsub(/^    /, '')
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
  
  file 'features/support/env_extn.rb', <<-EOS.gsub(/^    /, '')
    require "email_spec/cucumber"
    require File.dirname(__FILE__) + "/../../spec/blueprints"

    Before do
      FakeWeb.allow_net_connect = false
    end
  EOS
  
  file 'features/support/debug.rb', <<-EOS.gsub(/^    /, '')
    After do |scenario|
      $opened_page_count ||= 0
      if scenario.status == :failed && ($opened_page_count < 5)
        save_and_open_page
        $opened_page_count += 1
        if ENV['PAUSE']
          puts "Press any key to continue."
          STDIN.getc
        end
      end
    end
  EOS

  append_file 'spec/spec_helper.rb', <<-EOS.gsub(/^    /, '')
    require File.dirname(__FILE__) + '/blueprints'
  
    # When running specs in TextMate, provide an rputs method to cleanly print objects into HTML display
    # From http://talklikeaduck.denhaven2.com/2009/09/23/rspec-textmate-pro-tip
    module Kernel
      if ENV.keys.find {|env_var| env_var.start_with?("TM_")}
        def rputs(*args)
          puts( *["<pre>", args.collect {|a| CGI.escapeHTML(a.to_s)}, "</pre>"])
        end
        def rp(*args)
          puts( *["<pre>", args.collect {|a| CGI.escapeHTML(a.inspect)}, "</pre>"])
        end
      else
        alias_method :rputs, :puts
        alias_method :rp, :p
      end
    end
  EOS
  
  file 'spec/blueprints.rb', <<-EOS.gsub(/^    /, '')
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
  
  run 'mkdir spec/blueprints'
  file 'spec/blueprints/.gitignore', ''

# Initial controllers/views
  generate 'rspec_controller', 'home index'

  initializer "mailer.rb", <<-EOS.gsub(/^    /, '')
    mailer_options = YAML.load_file("\#{RAILS_ROOT}/config/mailer.yml")
    ActionMailer::Base.smtp_settings = mailer_options
  EOS
  file "config/mailer.yml", <<-EOS.gsub(/^    /, '')
    :address: mail.authsmtp.com
    :domain: #{domain}
    :authentication: :login
    :user_name: USERNAME
    :password: PASSWORD
  EOS

  run "rm -rf log"
  run "mkdir log"
  
# Run migrations
  rake 'db:migrate'
  rake 'db:test:clone'

  route "map.root :controller => 'home', :action => 'index'"
  
# Remove things we don't use
  FileUtils.rm_rf 'spec/views'

# Commit all work so far to the repository
  git :add => '.'
  git :commit => "-a -m 'Gems, plugins and config'"

  keep_all_empty_folders
  git :add => '.'
  git :commit => "-a -m 'Add .gitignore to all empty folders'"

# Copy database.yml for distribution use
  run "cp config/database.yml config/database.yml.example"
  git :add => '.'
  git :commit => "-a -m 'Example database.yml'"

  # Deploy!
  if ENV['HEROKU'] or highline.agree "Deploy to Heroku now?  "
    require "./heroku"
  end

end

