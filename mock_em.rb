require 'logger'
require 'cloud_gateway_support/logger_with_prefix'
require 'timecop'

module CloudGatewaySupport

  # Fake EM suitable for unit testing
  # Uses Timecop as it accelerates time.
  class MockEM

    TICK_MILLIS_STEP = 100

    def initialize(logger)
      @log = LoggerWithPrefix.new("MockEM", logger)

      @next_tick_procs = []
      @scheduled_tasks = ScheduledTasks.new(@log)
      @timer_objects = []
      @is_stopped = false
      set_clock(0)
      @shutdown_hooks = []

      @max_timer_count = 100000  #TODO: not honored
    end

    def run(&block)
      @reactor_running = true
      @is_stopped = false
      @log.info "run called. executing run block."

      safely_run { block.call }

      @log.info("Beginning tick loop.")
      @tick_count = 0
      while (!@is_stopped)
        @tick_count += 1
        set_clock(@clock_millis + TICK_MILLIS_STEP)
        @log.info "Preparing tick ##{@tick_count}, clock=#{@clock_millis}"

        this_tick_procs = @scheduled_tasks.pop_due_tasks(@clock_millis) + @next_tick_procs
        @next_tick_procs = []

        if this_tick_procs.empty?
          # accelerate time to next scheduled task
          next_time = @scheduled_tasks.time_of_next_task
          if next_time.nil?
            @log.info "Nothing left to do! Returning."
            break
          else
            @log.info "Nothing in this tick. Accelerating clock to: #{next_time}"
            set_clock(next_time)
            this_tick_procs = @scheduled_tasks.pop_due_tasks(@clock_millis)
          end
        end

        @log.info "Tick=#{@tick_count}, clock=#{@clock_millis} ms"
        this_tick_procs.each_with_index do |proc, index|
          @log.info "Executing tick proc ##{index+1}"
          safely_run { proc.call }
        end
      end
      @log.info("Finished tick loop. Returning.")
    ensure
      @reactor_running = false
    end

    def stop
      @log.info "stop called"
      @is_stopped = true
      @next_tick_procs = []
      @scheduled_tasks.clear_and_reset
      hooks = @shutdown_hooks
      @shutdown_hooks = []

      if hooks.count > 0
        @log.info "Executing #{hooks.count} shutdown hooks"
        hooks.reverse.each(&:call)
      end
    end

    def next_tick(proc = nil, &block)
      proc ||= block
      @log.info "Adding proc to next_tick"
      @next_tick_procs << proc
    end

    #TODO: don't use reuse_timer, factor it out to a private method
    #TODO: add support for proc & block, just like next_tick
    def add_timer(time_seconds, reuse_timer=nil, &block)
      timer = reuse_timer || MockTimer.new
      @log.info "Adding timer task: id=#{timer.id}, time_seconds=#{time_seconds}"
      @scheduled_tasks.add_task(@clock_millis + (time_seconds * 1000)) do
        if timer.is_cancelled
          @log.info "Skipping this timer task, it's already cancelled"
        else
          safely_run { block.call }
        end
      end
      @timer_objects << timer
      timer
    end

    #TODO: add support for proc & block, just like next_tick
    def add_periodic_timer(period_seconds, &block)
      timer = MockTimer.new
      @log.info "Creating periodic timer task: id=#{timer.id}, period_seconds=#{period_seconds}"

      recursive_block = nil
      recursive_block = lambda do
        if timer.is_cancelled
          @log.info "Skipping timer task id=#{timer.id}, it's already cancelled"
        else
          safely_run { block.call }
        end
        if !timer.is_cancelled
          @log.info "Rescheduling next run of periodic timer id=#{timer.id}"
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

    def reactor_running?
      !!(@reactor_running)
    end

    def get_max_timer_count
      @max_timer_count
    end

    def add_shutdown_hook(&block)
      @shutdown_hooks << block
    end

    def error_handler(proc = nil, &block)
      proc ||= block
      @log.info("")
      @error_handler = proc
    end

    # Simulates whatever EM.add_timer or EM.add_periodic_timer returns.
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


    # Keeps track of tasks to execute in the future, each one consisting of a timestamp and proc to execute.
    class ScheduledTasks
      ScheduledTask = Struct.new(:timestamp, :proc)

      def initialize(log)
        @log = log
        clear_and_reset
      end

      def add_task(timestamp_millis, &block)
        @tasks << ScheduledTask.new(timestamp_millis, block)
        @tasks = @tasks.sort_by(&:timestamp)
      end

      def pop_due_tasks(timestamp)
        due_tasks = @tasks.take_while {|t| t.timestamp <= timestamp }
        @tasks = @tasks - due_tasks
        @log.info("Popped #{due_tasks.count} due tasks. Clock=#{timestamp}, due_times=#{due_tasks.map(&:timestamp).inspect}")
        due_tasks.map(&:proc)
      end

      def time_of_next_task
        task = @tasks.first
        task && task.timestamp
      end

      def clear_and_reset
        @tasks = []
      end
    end


    private

    def safely_run(&block)
      begin
        block.call
      rescue => e
        @error_handler.call(e) if @error_handler
      rescue Exception => e
        @error_handler.call(e) if @error_handler
        raise e
      end
    end

    def set_clock(millis)
      @clock_millis = millis
      Timecop.freeze(millis)
    end

  end
end