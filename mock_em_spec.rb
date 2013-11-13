require 'spec/spec_helper'
require 'cloud_gateway_support/mock_em'

describe CloudGatewaySupport::MockEM do

  [true, false].each do |use_real_em|
    context "using #{use_real_em ? 'real' : 'fake'} em" do
      before(:each) do
        @logger = Logger.new(STDOUT)
        @em = use_real_em ? EM : CloudGatewaySupport::MockEM.new(@logger)
      end

      it "#run and #stop" do
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

      it "#next_tick" do
        after_stop = false
        @em.run do
          @em.next_tick do
            @em.stop
            after_stop = true
          end
        end
        after_stop.should == true
      end

      it "#add_timer" do
        counter = 0
        @em.run do
          @em.add_timer(1) do
            counter.should == 0
            counter += 1
            @em.add_timer(1) do
              counter.should == 1
              @em.stop
              counter +=1
            end
          end
        end
        counter.should == 2
      end

      it "#cancel_timer" do
        @em.run do
          timer = @em.add_timer(1) do
            fail
          end

          @em.cancel_timer(timer)

          @em.add_timer(2) do
            @em.stop
          end
        end
      end

      it "#add_periodic_timer" do
        @em.run do
          count = 0
          @em.add_periodic_timer(1) do
            count += 1
            if count > 5
              @em.stop
            end
          end
        end
      end

      it "cancelling periodic_timer" do
        @em.run do
          count = 0
          timer = nil
          timer = @em.add_periodic_timer(1) do
            count += 1
            if count >= 3
              @em.cancel_timer(timer)
            end
          end

          @em.add_timer(5) do
            @em.stop
            count.should == 3
          end
        end
      end

      it "#is_reactor_running?" do
        @em.reactor_running?.should == false
        @em.run do
          @em.reactor_running?.should == true
          @em.stop
          @em.reactor_running?.should == true
        end
        @em.reactor_running?.should == false
      end

      it "#add_shutdown_hook" do
        sequence = []
        @em.run do
          @em.add_shutdown_hook { sequence.push(1) }
          @em.add_shutdown_hook { sequence.push(2) }
          @em.stop
        end
        sequence.should == [2,1]
      end

    end
  end

end