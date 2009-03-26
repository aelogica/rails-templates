# mocra.rb
# from Dr Nic Williams @ http://mocra.com + http://drnicwilliams.com
# 
# Optional:
#  TWITTER=1    - install + setup twitter_auth instead of restful_authentication
#  SKIP_GEMS=1  - don't install gems (useful if you know they are already installed)
#
# based on daring.rb from Peter Cooper

# Link to local copy of edge rails
  # inside('vendor') { run 'ln -s ~/dev/rails/rails rails' }

# Delete unnecessary files
  run "rm README"
  run "rm public/index.html"
  run "rm public/favicon.ico"
  run "rm public/robots.txt"
  run "rm -f public/javascripts/*"

# Download JQuery
  run "curl -L http://jqueryjs.googlecode.com/files/jquery-1.3.1.min.js > public/javascripts/jquery.js"
  run "curl -L http://jqueryjs.googlecode.com/svn/trunk/plugins/form/jquery.form.js > public/javascripts/jquery.form.js"
  run "curl -L http://plugins.jquery.com/files/jquery.template.js.txt > public/javascripts/jquery.template.js"

# Set up git repository
  git :init
  git :add => '.'
  
# Copy database.yml for distribution use
  run "cp config/database.yml config/database.yml.example"
  
# Set up .gitignore files
  run "touch tmp/.gitignore log/.gitignore vendor/.gitignore"
  run %{find . -type d -empty | grep -v "vendor" | grep -v ".git" | grep -v "tmp" | xargs -I xxx touch xxx/.gitignore}
  file '.gitignore', <<-END
.DS_Store
log/*.log
tmp/**/*
config/database.yml
db/*.sqlite3
END


# Set up session store initializer
  initializer 'session_store.rb', <<-END
ActionController::Base.session = { :session_key => '_#{(1..6).map { |x| (65 + rand(26)).chr }.join}_session', :secret => '#{(1..40).map { |x| (65 + rand(26)).chr }.join}' }
ActionController::Base.session_store = :active_record_store
  END

# Install submoduled plugins
  plugin 'rspec', :git => 'git://github.com/dchelimsky/rspec.git', :submodule => true
  plugin 'rspec-rails', :git => 'git://github.com/dchelimsky/rspec-rails.git', :submodule => true
  plugin 'will_paginate', :git => 'git://github.com/mislav/will_paginate.git', :submodule => true
  plugin 'state_machine', :git => 'git://github.com/pluginaweek/state_machine.git', :submodule => true
  plugin 'quietbacktrace', :git => 'git://github.com/thoughtbot/quietbacktrace.git', :submodule => true
  plugin 'machinist', :git => 'git://github.com/notahat/machinist.git', :submodule => true
  plugin 'paperclip', :git => 'git://github.com/thoughtbot/paperclip.git', :submodule => true

# Install all gems
  gem 'sqlite3-ruby', :lib => 'sqlite3'
  if ENV['TWITTER']
    gem 'twitter-auth', :lib => 'twitter_auth'
  else                
    gem 'authenticated', 'User --include-activation --rspec'
  end

  rake 'gems:install', :sudo => true unless ENV['SKIP_GEMS']


# Set up sessions, RSpec, user model, OpenID, etc, and run migrations
  rake 'db:sessions:create'
  generate "rspec"
  generate "cucumber"
  if ENV['TWITTER']
    generate "twitter_auth --oauth"
  else
    generate "authenticated", "user session"
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

  file 'app/views/home/index.html.erb', '<%= link_to "Protected Area", :controller => :protected %>'
  file 'app/views/protected/index.html.erb', '<h3><%= current_user.login %></h3>'
  
  if ENV['TWITTER']
    append_file 'config/environments/development.rb', "\n\nOpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE"
    append_file 'config/environments/test.rb', "\n\nOpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE"
  end
  
  file 'spec/blueprints.rb', ''

  rake 'db:migrate'

# Routes
  unless ENV['TWITTER']
    route "map.signup  '/signup', :controller => 'users',   :action => 'new'"
    route "map.login  '/login',  :controller => 'session', :action => 'new'"
    route "map.logout '/logout', :controller => 'session', :action => 'destroy'"
    route "map.activate '/activate/:activation_code', :controller => 'users', :action => 'activate', :activation_code => nil"
  end
  
  route "map.root :controller => 'home', :action => 'index'"
  

# Initialize submodules
  git :submodule => "init"

# Commit all work so far to the repository
  git :add => '.'
  git :commit => "-a -m 'Initial commit'"

  if ENV['TWITTER']
    puts "The next step is to edit config/twitter_auth.yml to reflect our OAuth client key and secret (to register your application log in to Twitter and visit http://twitter.com/oauth_clients)."
    `open http://intridea.com/2009/3/23/twitter-auth-for-near-instant-twitter-apps`
  end
  
# Success!
  puts "SUCCESS!"