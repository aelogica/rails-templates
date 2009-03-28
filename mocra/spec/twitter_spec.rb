require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "template_runner" do
  before(:each) do
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
      describe "error" do
        before(:each) do
          @message = <<-EOS.gsub(/^        /, '')
          Unable to register this application. Check your registration settings.
          * Name has already been taken
          EOS
        end
        describe "and parse keys" do
          before(:each) do
            @keys = @runner.parse_keys(@message)
          end
          it { @keys[:key].should == "TWITTER_CONSUMERKEY" }
          it { @keys[:secret].should == "TWITTER_CONSUMERSECRET" }
        end
      end
    end
    describe "run template" do
      before(:each) do
        @runner.highline.should_receive(:choose).twice.and_return("drnic", "mocra-primary")
        @runner.on_command(:run, "twitter register_oauth drnic 'rails-templates' http://rails-templates.mocra.com 'This is a cool app' organization='Mocra' organization_url=http://mocra.com") do
          <<-EOS.gsub(/^          /, '')
          Nice! You've registered your application successfully.
          Consumer key:    CONSUMERKEY
          Consumer secret: CONSUMERSECRET
          EOS
        end
        @runner.should_receive(:slices_name_and_ip).ordered.and_return({
          'mocra-primary' => '123.123.123.123',
          'mocra-secondary' => '65.65.65.65'
        })

        @runner.run_template
        @log = @runner.full_log
      end
      
      it { @log.should =~ %r{file  config/deploy.rb} }
      it { @log.should =~ %r{executing  twitter register_oauth drnic 'rails-templates' http://rails-templates.mocra.com 'This is a cool app' organization='Mocra' organization_url=http://mocra.com} }
      it { @runner.files['config/twitter_auth.yml'].should_not be_nil }
      it { @runner.files['config/twitter_auth.yml'].should =~ %r{oauth_consumer_key: CONSUMERKEY} }
      it { @runner.files['config/twitter_auth.yml'].should =~ %r{oauth_consumer_secret: CONSUMERSECRET} }
      it { @log.should =~ %r{executing  slicehost-dns add_cname mocra.com rails-templates mocra-primary}}
      it { @log.should =~ %r{executing  github create-from-local} }
    end
  end
end
