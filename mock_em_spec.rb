require 'spec/spec_helper'
require 'cloud_gateway_support/mock_em'

describe CloudGatewaySupport::MockEM do

  [true, false].each do |use_real_em|
    context "using #{use_real_em ? 'real' : 'fake'} em" do
      before(:each) do
        @logger = Logger.new(STDOUT)
        @em = use_real_em ? EM : CloudGatewaySupport::MockEM.new(@logger)
      end

      it "should run and stop" do
        inside_run = false
        after_stop = false
        @em.run do
          inside_run = true
          @em.stop
          after_stop = true
        end
        inside_run.should == true
        after_stop.should == true
      end

      it "should support next_tick" do
        after_stop = false
        @em.run do
          @em.next_tick do
            @em.stop
            after_stop = true
          end
        end
        after_stop.should == true
      end

      it "should support add_timer" do
        after_stop = false
        @em.run do
          @em.add_timer(2) do
            @em.stop
            after_stop = true
          end
        end
        after_stop.should == true
      end
    end
  end

end