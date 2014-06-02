require 'spec/spec_helper'
require 'mock_em/mock_em'

describe MockEM::MockEM do

  # Runs all of these specs on both real EM and MockEM,
  # so we can immediately notice if their behavior is not identical.
  [true, false].each do |use_real_em|
    context "using #{use_real_em ? 'real' : 'fake'} em" do

      before(:each) do
        @logger = Logger.new(STDOUT)
        @em = use_real_em ? EM : MockEM::MockEM.new(@logger, Timecop)
      end
      after(:each) do
        Timecop.return
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

      it "#next_tick &block" do
        after_stop = false
        @em.run do
          @em.next_tick do
            @em.stop
            after_stop = true
          end
        end
        after_stop.should == true
      end

      it "#next_tick proc" do
        after_stop = false
        proc = proc {
          @em.stop
          after_stop = true
        }
        @em.run do
          @em.next_tick(proc)
        end
        after_stop.should == true
      end

      it "#add_timer &block" do
        counter = 0
        @em.run do
          @em.add_timer(0.1) do
            counter.should == 0
            counter += 1
            @em.add_timer(0.1) do
              counter.should == 1
              @em.stop
              counter +=1
            end
          end
        end
        counter.should == 2
      end

      it "#add_timer proc" do
        counter = 0
        @em.run do
          proc1 = proc do
            counter.should == 0
            counter += 1
            proc2 = proc do
              counter.should == 1
              @em.stop
              counter +=1
            end
            @em.add_timer(0.1, proc2)
          end
          @em.add_timer(0.1, proc1)
        end
        counter.should == 2
      end

      it "#cancel_timer" do
        @em.run do
          timer = @em.add_timer(0.1) do
            fail
          end

          @em.cancel_timer(timer)

          @em.add_timer(0.3) do
            @em.stop
          end
        end
      end

      it "#add_periodic_timer &block" do
        count = 0
        @em.run do
          @em.add_periodic_timer(0.1) do
            count += 1
            if count > 5
              @em.stop
            end
          end
        end
        count.should == 6
      end

      it "#add_periodic_timer proc" do
        count = 0
        @em.run do
          proc1 = proc do
            count += 1
            if count > 5
              @em.stop
            end
          end
          @logger.info "adding timer"

          @em.add_periodic_timer(0.1, proc1)
        end
        count.should == 6
      end

      it "cancelling periodic_timer" do
        @em.run do
          count = 0
          timer = nil
          timer = @em.add_periodic_timer(0.1) do
            count += 1
            if count >= 3
              @em.cancel_timer(timer)
            end
          end

          @em.add_timer(0.5) do
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

      it "#get_max_timer_count" do
        @em.get_max_timer_count.should == 100000
      end

      it "#error_handler" do
        error_count = 0
        @em.error_handler do |error|
          @logger.info "Caught error: #{error.inspect}"
          error.message.should =~ /fake_error/
          error_count += 1
        end

        @em.run do
          @em.next_tick do
            @em.next_tick do
              @em.stop
            end
            raise "fake_error_2"
          end
          raise "fake_error_1"
        end

        error_count.should == 2
      end

      it "#error_handler not defined, should re-raise error" do
        lambda do
          @em.run do
            @em.next_tick do
              @em.next_tick do
                raise "error"
              end
            end
          end
        end.should raise_error
      end

    end
  end
end
