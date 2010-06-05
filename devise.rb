load File.join(File.dirname(root), File.dirname(template), "template_helpers.rb")

heroku_gem 'devise'

generate 'devise_install'
append_file 'config/environments/development.rb', <<-EOS.gsub(/^  /, '')
  
  config.action_mailer.default_url_options = { :host => '#{app_name}.local' }
EOS
generate 'devise', 'User'
create_users_file = Dir['db/migrate/*_create_users.rb'].first
file create_users_file, <<-RUBY.gsub(/^  /, '')
  class DeviseCreateUsers < ActiveRecord::Migration
    def self.up
      create_table(:users) do |t|
        t.string :name
        
        t.database_authenticatable :null => false
        t.confirmable
        t.recoverable
        t.rememberable
        t.trackable
        # t.lockable

        t.timestamps
      end

      add_index :users, :email,                :unique => true
      add_index :users, :confirmation_token,   :unique => true
      add_index :users, :reset_password_token, :unique => true
      # add_index :users, :unlock_token,         :unique => true
    end

    def self.down
      drop_table :users
    end
  end
RUBY
file 'app/models/user.rb', <<-EOS.gsub(/^  /, '')
  class User < ActiveRecord::Base
    # Include default devise modules. Others available are:
    # :http_authenticatable, :token_authenticatable, :lockable, :timeoutable and :activatable
    devise :registerable, :database_authenticatable, :recoverable,
           :rememberable, :trackable, :validatable, :lockable,
           :http_authenticatable

    # Setup accessible (or protected) attributes for your model
    attr_accessible :email, :password, :password_confirmation, :name
    
  end
EOS
file 'spec/models/user_spec.rb', <<-EOS.gsub(/^  /, '')
  require 'spec_helper'

  describe User do
    before(:each) do
      @valid_attributes = {
        :login                 => "drnic",
        :email                 => "drnic@mocra.com",
        :password              => "password",
        :password_confirmation => "password"
      }
    end

    it "should create a new instance given valid attributes" do
      User.create!(@valid_attributes)
    end
  end
EOS


gsub_file("app/controllers/application_controller.rb", /class ApplicationController < ActionController::Base/mi) do
  <<-EOS.gsub(/^  /, '')
  class ApplicationController < ActionController::Base
    before_filter :authenticate_user!
  EOS
end



