# mocra.rb
# from Dr Nic Williams @ http://mocra.com + http://drnicwilliams.com
# 
# WARNING - being upgraded to rails3
# 
# Optional:
#  DOMAIN       - parent domain (default: mocra.com)
#  SKIP_GEMS=1  - don't install gems (useful if you know they are already installed)
#  DB=mysql     - else sqlite3 by default
#  NO_SUDO=1    - don't use sudo to install gems
#
#  The following are just for twitter oauth registration:
#  ORGANIZATION - name of your company (default: Mocra)
#  DESCRIPTION  - description of your app (default: This is a cool app)
#
# Required gems for this template:
#   gem install highline
#   gem install deprec
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
  app_name      = File.basename(File.expand_path(app_path))
  application   = app_name.gsub(/[_-]/, ' ').titleize
  app_subdomain = app_name.gsub(/[_\s]/, '-').downcase
  app_db        = app_name.gsub(/[-\s]/, '_').downcase
  domain        = 'heroku.com'
  app_url       = "#{app_subdomain}.#{domain}"
  organization  = ENV['ORGANIZATION'] || "Mocra"
  description   = ENV['DESCRIPTION'] || 'This is a cool app'
  skip_gems     = ENV['SKIP_GEMS']
  sudo          = ENV['NO_SUDO'] ? '' : 'sudo '

  github_user = `git config --get github.user`.strip
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
  
  authlogic      = false
  authentication = false
  
# Delete unnecessary files
  run "rm README"
  run "rm public/index.html"
  run "rm public/favicon.ico"
  run "rm public/robots.txt"
  run "rm .gitignore"
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
# Copy database.yml for distribution use
  run "cp config/database.yml config/database.yml.example"
  
# Set up .gitignore files
  run "touch tmp/.gitignore log/.gitignore vendor/.gitignore"
  run %{find . -type d -empty | grep -v "vendor" | grep -v ".git" | grep -v "tmp" | xargs -I xxx touch xxx/.gitignore}
  file '.gitignore', <<-EOS.gsub(/^    /, '')
    .bundle
    db/*.sqlite3
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
  
# Prepare for required gems

  # run "rm Gemfile"
  # run "touch Gemfile"
  # add_source "http://gemcutter.org"
  # 
  # gem "rails" #, :git => "git://github.com/rails/rails"
  # gem "rack"
  # append_file "Gemfile", "git git://github.com/indirect/rails3-generators.git"
  # gem "rails3-generators"
  
# Authentication gems/plugins

  gem 'pg' # to make heroku happy in it's beta program
  
  if authlogic
    gem 'authlogic'
  end

# Set up sessions
  rake 'db:create:all'
  rake 'db:sessions:create'

# Common gems/plugins

  gem 'inherited_resources'
  gem 'will_paginate'
  gem 'formtastic'
  gem "haml"
  # 
  # plugin 'validation_reflection', :git => 'git://github.com/redinger/validation_reflection.git'

# Gems - testing

  group :test do
    gem "capybara", :require => false
    gem "rspec", :require => false
    gem "rspec-rails", :require => 'spec/rails'
    gem 'email_spec'
    gem 'machinist'
    gem 'fakeweb'
    gem 'faker'
  end
  
# Make sure all these gems are actually installed locally

  # generate "haml"
  # run "haml --rails ."
  # run "rm -rf vendor/plugins/haml" # use gem install
  # generate "rspec"
  # generate "email_spec"
  # generate "cucumber", "--capybara"

# Gems - cucumber
  
  group :cucumber do
    gem "cucumber", :require => false
    gem "capybara", :require => false
    gem "rspec",    :require => false
    gem "rspec-rails", :require => 'spec/rails'
    gem 'email_spec'
    gem 'machinist'
    gem 'fakeweb'
    gem 'faker'
  end
  
# Install plugins

  # plugin 'blue_ridge', :git => 'git://github.com/drnic/blue-ridge.git'
  # generate "blue_ridge"

# Hook for layouts, assets

  # generate 'app_layout'



  if authentication
    file 'app/views/home/index.html.haml', <<-EOS.gsub(/^      /, '')
      %h1 Welcome!
      %p
        = link_to "Protected", :controller => :protected
    EOS
  else
    file 'app/views/home/index.html.haml', '%h1 Welcome!'
  end
  
# Mailer dummy config
  initializer "mailer.rb", <<-EOS.gsub(/^    /, '')
    mailer_options = YAML.load_file("\#{Rails.root}/config/mailer.yml")
    ActionMailer::Base.smtp_settings = mailer_options
  EOS
  file "config/mailer.yml", <<-EOS.gsub(/^    /, '')
    :address: mail.authsmtp.com
    :domain: #{domain}
    :authentication: :login
    :user_name: USERNAME
    :password: PASSWORD
  EOS

# Run migrations
  rake 'db:migrate'
  rake 'db:test:clone'

# Routes
  if authlogic
    route "resource :password_reset"
    route "resource :user_session"
  end
  
  route 'root :to => "home#index"'
  
# Remove things we don't use
  FileUtils.rm_rf 'spec/views'
  
  bundle :install

# Commit all work so far to the repository
  git :add => '.'
  git :commit => "-a -m 'Gems, plugins and config'"

  # Deploy!
  if highline.agree "Deploy to Heroku now?  "
    heroku :create, "#{app_subdomain} --stack bamboo-ree-1.8.7"
    heroku :"sharing:add", "dev@mocra.com"
    heroku :"sharing:transfer", "dev@mocra.com"
    heroku :"addons:add", "custom_domains:basic"
    if highline.agree "Add all Mocra staff?  "
      ["bjeanes@mocra.com", "chendo@mocra.com", "odindutton@gmail.com"].each do |user|
        heroku :"sharing:add", user
      end
    end
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

class GemfileGroup
  def initialize(runner, group_name)
    @runner = runner
    @group_name = group_name
  end
  def gem(name, options = {})
    @runner.gem(name, options.merge({:group => @group_name.to_s}))
  end
end

def group(group_name, &block)
  proxy = GemfileGroup.new(self, group_name)
  proxy.instance_eval(&block)
end

def bundle(cmd, arguments="")
  run "bundle #{cmd} #{arguments}"
end

def heroku(cmd, arguments="")
  run "heroku #{cmd} #{arguments}"
end

def run_template
  @store_template.call
end


run_template unless ENV['TEST_MODE'] # hold off running the template whilst in unit testing mode
