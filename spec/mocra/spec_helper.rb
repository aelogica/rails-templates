require File.dirname(__FILE__) + "/../spec_helper"

def setup_template_runner(template_name = "mocra.rb")
  ENV['TEST_MODE'] = '1'
  @template = File.dirname(__FILE__) + "/../../#{template_name}"
  @runner = Rails::TemplateRunner.new(@template)
end