require 'logger'
require 'mock_em/logger_with_prefix'
require 'timecop'

module MockEM

  # Fake EM suitable for unit testing.
  # Uses Timecop to accelerate time. Should run Timecop.return after spec, just to be safe.
  class MockEM

    # @param [Timecop] timecop
    def initialize(logger, timecop)
      @log = LoggerWithPrefix.new("MockEM", logger)
      @timecop = timecop

      @next_tick_procs = []
      @scheduled_tasks = ScheduledTasks.new(@log)
      @timer_objects   = []
      @shutdown_hooks  = []
      @is_stopped      = false

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

        due_tasks = @scheduled_tasks.pop_due_tasks(now_millis)
        @log.info "Tick ##{@tick_count}, clock=#{now_millis}, due_tasks=#{due_tasks.count}, next_tick_procs=#{@next_tick_procs.count}"
        this_tick_procs = due_tasks + @next_tick_procs
        @next_tick_procs = []

        if this_tick_procs.empty?
          # accelerate time to next scheduled task
          next_time = @scheduled_tasks.time_of_next_task
          if next_time.nil?
            @log.info "Nothing left to do! Returning."
            break
          else
            delta = next_time - now_millis
            @log.info "Nothing in this tick. Accelerating clock by #{delta / 1000.0}s to: #{next_time}"
            set_clock(next_time)
          end
        end

        this_tick_procs.each_with_index do |proc, index|
          @log.info "Executing tick proc ##{index+1}"
          safely_run { proc.call }
        end
      end
      @log.info("Finished tick loop. Returning.")
    ensure
      @reactor_running = false
      future_time = now_millis
      @timecop.return
      @log.debug "MockEM saved you #{(future_time - now_millis) / 1000} seconds."
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

    def add_timer(delay_seconds, proc = nil, &block)
      add_timer_internal(delay_seconds, nil, proc, &block)
    end

    def add_periodic_timer(period_seconds, proc = nil, &block)
      proc ||= block
      timer = MockTimer.new
      @log.info "Creating periodic timer task: id=#{timer.id}, period_seconds=#{period_seconds}"

      recursive_block = nil
      recursive_block = lambda do
        safely_run { proc.call }
        if !timer.is_cancelled
          @log.info "Rescheduling next run of periodic timer id=#{timer.id}"
          add_timer_internal(period_seconds, timer, recursive_block)
        end
      end

      add_timer_internal(period_seconds, timer, recursive_block)
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
      @log.info("Setting error_handler")
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
        if @error_handler
          @error_handler.call(e)
        else
          raise e
        end
      rescue Exception => e
        @error_handler.call(e) if @error_handler
        raise e
      end
    end

    def set_clock(millis)
      @timecop.travel(Time.at(millis / 1000.0))
    end

    def now_millis
      (Time.now.utc.to_f * 1000.0).to_i
    end

    # same as add_timer, but adds an optional parameter: reuse_timer
    def add_timer_internal(delay_seconds, reuse_timer, proc = nil, &block)
      proc ||= block
      timer = reuse_timer || MockTimer.new
      @log.info "Adding timer task: id=#{timer.id}, delay_seconds=#{delay_seconds}"
      @scheduled_tasks.add_task(now_millis + (delay_seconds * 1000)) do
        if timer.is_cancelled
          @log.debug "Skipping this timer task, it's already cancelled"
        else
          safely_run { proc.call }
        end
      end
      @timer_objects << timer
      timer
    end

  end
end