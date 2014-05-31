module MockEM

  # Logs all messages with the specified prefix.
  # Warning: this is a not a full-fledged Logger implementation, it just logs string messages.
  class LoggerWithPrefix

    attr_reader :prefix
    attr_reader :raw_logger

    def initialize(prefix, logger)
      @prefix     = prefix
      @raw_logger = logger
    end

    def debug(msg); log_with_prefix(:debug, msg)  end
    def info(msg);  log_with_prefix(:info,  msg)  end
    def warn(msg);  log_with_prefix(:warn,  msg)  end
    def error(msg); log_with_prefix(:error, msg)  end

    private

    def log_with_prefix(level, msg)
      @raw_logger.__send__(level, "#{prefix}: #{msg}")
    end
  end

end