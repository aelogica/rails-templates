require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "template_runner" do
  before(:each) do
    ENV['NO_RUN'] = '1'
    setup_template_runner
  end
  describe "twitter" do
    before(:each) do
      ENV['TWITTER'] = '1'
    end
    describe "regiester_oauth" do
      describe "success" do
        before(:each) do
          @message = <<-EOS.gsub(/^        /, '')
          Nice! You've registered your application successfully.
          Consumer key:    CONSUMERKEY
          Consumer secret: CONSUMERSECRET
          EOS
        end
        describe "and parse keys" do
          before(:each) do
            @keys = @runner.parse_keys(@message)
          end
          it { @keys[:key].should == "CONSUMERKEY" }
          it { @keys[:secret].should == "CONSUMERSECRET" }
        end
      end
    end
  end
end
