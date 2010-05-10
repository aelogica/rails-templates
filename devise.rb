heroku_gem 'devise'

generate 'devise_install'
append_file 'config/environments/development.rb', <<-EOS.gsub(/^  /, '')
  config.action_mailer.default_url_options = { :host => '#{app_name}.local' }
EOS
generate 'devise', 'User'
create_users_file = Dir['db/migrate/*_create_users.rb'].first
file create_users_file, <<-EOS.gsub(/^  /, '')
  class CreateUsers < ActiveRecord::Migration
    def self.up
      create_table :users do |t|
        t.string    :login,               :null => false                # optional, you can use email instead, or both
        t.string    :email,               :null => false                # optional, you can use login instead, or both
        t.string    :crypted_password,    :null => false                # optional, see below
        t.string    :password_salt,       :null => false                # optional, but highly recommended
        t.string    :persistence_token,   :null => false                # required
        t.string    :single_access_token, :null => false                # optional, see Authlogic::Session::Params
        t.string    :perishable_token,    :null => false                # optional, see Authlogic::Session::Perishability

        # Magic columns, just like ActiveRecord's created_at and updated_at. These are automatically maintained by Authlogic if they are present.
        t.integer   :login_count,         :null => false, :default => 0 # optional, see Authlogic::Session::MagicColumns
        t.integer   :failed_login_count,  :null => false, :default => 0 # optional, see Authlogic::Session::MagicColumns
        t.datetime  :last_request_at                                    # optional, see Authlogic::Session::MagicColumns
        t.datetime  :current_login_at                                   # optional, see Authlogic::Session::MagicColumns
        t.datetime  :last_login_at                                      # optional, see Authlogic::Session::MagicColumns
        t.string    :current_login_ip                                   # optional, see Authlogic::Session::MagicColumns
        t.string    :last_login_ip                                      # optional, see Authlogic::Session::MagicColumns

        t.timestamps
      end

      add_index :users, :email
      add_index :users, :login, :unique => true
    end

    def self.down
      drop_table :users
    end
  end
EOS
file 'app/models/user.rb', <<-EOS.gsub(/^  /, '')
  class User < ActiveRecord::Base
    acts_as_authentic
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


file 'app/controllers/application_controller.rb', <<-EOS.gsub(/^  /, '')
  class ApplicationController < ActionController::Base
    helper :all # include all helpers, all the time
    protect_from_forgery # See ActionController::RequestForgeryProtection for details

    private
      def current_user_session
        return @current_user_session if defined?(@current_user_session)
        @current_user_session = UserSession.find
      end

      def current_user
        return @current_user if defined?(@current_user)
        @current_user = current_user_session && current_user_session.user
      end

      def login_required
        unless current_user
          if current_user_session && current_user_session.stale?
            flash[:notice] = "Your session has been logged out automatically"
          else
            flash[:error] = "You must be logged in to access this page"
          end

          store_location
          redirect_to new_user_session_url
          return false
        end
      end

      def store_location
        session[:return_to] = request.request_uri
      end

      def redirect_back_or_default(default)
        redirect_to(session[:return_to] || default)
        session[:return_to] = nil
      end
  end
EOS
generate 'rspec_controller', 'user_sessions'
file 'app/controllers/user_sessions_controller.rb', <<-EOS.gsub(/^  /, '')
  class UserSessionsController < ApplicationController
    def new
      @user_session = UserSession.new
    end

    def create
      @user_session = UserSession.new(params[:user_session])
      if @user_session.save
        redirect_to account_url
      else
        render :action => :new
      end
    end

    def destroy
      current_user_session.destroy
      redirect_to new_user_session_url
    end
  end
EOS
file 'app/views/user_sessions/new.html.haml', <<-EOS.gsub(/^  /, '')
  - semantic_form_for @user_session, :url => user_session_path do |f|
    - if @user_session.errors[:base].any?
      .errorExplanation
        %ul
          %li= @user_session.errors[:base]

    - f.inputs do
      = f.input :login, :required => true
      = f.input :password, :required => true
      = f.input :remember_me, :as => :boolean
    - f.buttons do
      = f.commit_button "Log in"
      %li= link_to "Forgot password?", new_password_reset_path
EOS
