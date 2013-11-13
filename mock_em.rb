require 'logger'
require 'cloud_gateway_support/logger_with_prefix'

module CloudGatewaySupport
  # Fake EM suitable for unit testing
  class MockEM

    TICK_MILLIS_STEP = 100

    def initialize(logger)
      @logger = LoggerWithPrefix.new("MockEM", logger)

      @next_tick_procs = []
      @scheduled_tasks = ScheduledTasks.new(@logger)
      @timer_objects = []
      @is_stopped = false
      @clock_millis = 0
    end

    def run(&block)
      @is_stopped = false
      @logger.info "run called. executing run block."
      block.call

      @logger.info("Beginning tick loop.")
      @tick_count = 0
      while (!@is_stopped)
        @tick_count += 1
        @clock_millis += TICK_MILLIS_STEP
        @logger.info "Preparing tick ##{@tick_count}, clock=#{@clock_millis}"

        this_tick_procs = @scheduled_tasks.pop_due_tasks(@clock_millis) + @next_tick_procs
        @next_tick_procs = []

        if this_tick_procs.empty?
          # accelerate time to next scheduled task
          next_time = @scheduled_tasks.time_of_next_task
          if next_time.nil?
            @logger.info "Nothing left to do! Returning."
            break
          else
            @logger.info "Nothing in this tick. Accelerating clock to: #{next_time}"
            @clock_millis = next_time
            this_tick_procs = @scheduled_tasks.pop_due_tasks(@clock_millis)
          end
        end

        @logger.info "Tick=#{@tick_count}, clock=#{@clock_millis} ms"
        this_tick_procs.each_with_index do |proc, index|
          @logger.info "Executing tick proc ##{index+1}"
          proc.call
        end
      end
      @logger.info("Finished tick loop. Returning.")
    end

    def stop
      @logger.info "stop called"
      @is_stopped = true
      @next_tick_procs = []
      @scheduled_tasks = ScheduledTasks.new(@logger)
    end

    def next_tick(&block)
      @logger.info "Adding proc to next_tick"
      @next_tick_procs << block
    end

    def add_timer(time_seconds, reuse_timer=nil, &block)
      timer = reuse_timer || MockTimer.new
      @logger.info "Adding timer task: id=#{timer.id}, time_seconds=#{time_seconds}"
      @scheduled_tasks.add_task(@clock_millis + (time_seconds * 1000)) do
        if timer.is_cancelled
          @logger.info "Skipping this timer task, it's already cancelled"
        else
          block.call
        end
      end
      @timer_objects << timer
      timer
    end

    def add_periodic_timer(period_seconds, &block)
      timer = MockTimer.new
      @logger.info "Creating periodic timer task: id=#{timer.id}, period_seconds=#{period_seconds}"

      recursive_block = nil
      recursive_block = lambda do
        if timer.is_cancelled
          @logger.info "Skipping timer task id=#{timer.id}, it's already cancelled"
        else
          block.call
        end
        if !timer.is_cancelled
          @logger.info "Rescheduling next run of periodic timer id=#{timer.id}"
          add_timer(period_seconds, timer, &recursive_block)
        end
      end

      add_timer(period_seconds, timer, &recursive_block)
    end

    def cancel_timer(timer)
      #TODO: support looking up by timer ID as well
      @timer_objects.delete(timer)
      timer.cancel
    end


    class MockTimer

      @@id_seq = 0

      attr_reader :id, :is_cancelled

      def initialize
        @is_cancelled = false
        @id = @@id_seq += 1
      end

      def cancel
        @is_cancelled = true
      end
    end

    class ScheduledTasks
      ScheduledTask = Struct.new(:timestamp, :proc)

      def initialize(logger)
        @logger = logger
        @tasks = []
      end

      def add_task(timestamp_millis, &block)
        @tasks << ScheduledTask.new(timestamp_millis, block)
        @tasks = @tasks.sort_by(&:timestamp)
      end

      def pop_due_tasks(timestamp)
        due_tasks = @tasks.take_while {|t| t.timestamp <= timestamp }
        @tasks = @tasks - due_tasks
        @logger.info("Popped #{due_tasks.count} due tasks. Clock=#{timestamp}, due_times=#{due_tasks.map(&:timestamp).inspect}")
        due_tasks.map(&:proc)
      end

      def time_of_next_task
        task = @tasks.first
        task && task.timestamp
      end
    end
  end
end