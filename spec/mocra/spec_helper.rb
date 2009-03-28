require File.dirname(__FILE__) + "/../spec_helper"

def setup_template_runner
  ENV['TEST_MODE'] = '1'
  @template = File.dirname(__FILE__) + "/../../mocra.rb"
  @runner = Rails::TemplateRunner.new(@template)
end