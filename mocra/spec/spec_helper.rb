require 'spec'
require 'rails_generator/generators/applications/app/template_runner'

Spec::Runner.configure do |config|
  # == Mock Framework
  #
  # RSpec uses it's own mocking framework by default. If you prefer to
  # use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
  #
  # == Notes
  # 
  # For more information take a look at Spec::Runner::Configuration and Spec::Runner
end

class Rails::TemplateRunner
  def initialize(template, root = '') # :nodoc:
    @root = File.expand_path(File.directory?(root) ? root : File.join(Dir.pwd, root))
  end
end

def setup_template_runner
  @template = File.dirname(__FILE__) + "/../../mocra.rb"
  @runner = Rails::TemplateRunner.new(@template)
  %w[file
  plugin
  gem
  environment
  git
  vendor
  lib
  rakefile
  initializer
  generate
  run
  run_ruby_script
  rake
  capify!
  freeze!
  route
  ask
  yes?
  no?
  gsub_file
  append_file
  destination_path
  log
  logger].each { |template_helper| @runner.stub!(template_helper.to_sym) }
  @runner.load_template(@template)
end