require 'logger'

module CloudGatewaySupport
  # Fake EM suitable for unit testing
  class MockEM

    TICK_MILLIS_STEP = 100

    def initialize(logger)
      @logger = logger

      @next_tick_procs = []
      @scheduled_tasks = ScheduledTasks.new(@logger)
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
        # prepare this tick
        @tick_count += 1
        @clock_millis += TICK_MILLIS_STEP

        this_tick_procs = @scheduled_tasks.pop_due_tasks(@clock_millis) + @next_tick_procs
        @next_tick_procs = []

        if this_tick_procs.empty?
          # accelerate time to next scheduled task
          next_time = @scheduled_tasks.time_of_next_task
          if next_time.nil?
            @logger.info "Nothing left to do! Returning."
            break
          else
            @logger.info "Accelerating clock to: #{next_time}"
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

    def add_timer(time_seconds, &block)
      @logger.info "Adding timer task: time_seconds=#{time_seconds}"
      @scheduled_tasks.add_task(@clock_millis + (time_seconds * 1000), &block)
    end

    def add_periodic_timer(period, &block)
    end

    def cancel_timer(timer)
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
        due_tasks = @tasks.delete_if {|t| t.timestamp <= timestamp }
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