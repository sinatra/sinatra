# Adapted from Merb greatness

module Sinatra

  class Logger
    module Severity
      DEBUG = 0
      INFO = 1
      WARN = 2
      ERROR = 3
      FATAL = 4
      UNKNOWN = 5
    end
    include Severity

    attr_accessor :level
    attr_reader :buffer
    
    def initialize(log, level = DEBUG)
      @level = level
      @buffer = []
      if log.respond_to?(:write)
        @log = log
      elsif File.exist?(log)
        @log = open(log, (File::WRONLY | File::APPEND))
        @log.sync = true
      else
        @log = open(log, (File::WRONLY | File::APPEND | File::CREAT))
        @log.sync = true
        @log.write("# Logfile created on %s\n" % [Time.now.to_s])
      end
    end
    
    def flush
      unless @buffer.size == 0
        @aio ||= !Sinatra.config.to_s.match(/development|test/) # && !RUBY_PLATFORM.match(/java|mswin/) &&
                 @log.respond_to?(:write_nonblock)
        if @aio
          @log.write_nonblock(@buffer.slice!(0..-1).to_s)
        else
          @log.write(@buffer.slice!(0..-1).to_s)
        end
      end
    end
    
    def close
      flush
      @log.close if @log.respond_to?(:close)
      @log = nil
    end

    def add(severity, message = nil, progname = nil, &block)
      return if @level > severity
      message = (message || (block && block.call) || progname).to_s
      # If a newline is necessary then create a new message ending with a newline.
      # Ensures that the original message is not mutated.
      message = "#{message}\n" unless message[-1] == ?\n
      @buffer << message
      message
    end
    
    Severity.constants.each do |severity|
      class_eval <<-EOT
        def #{severity.downcase}(message = nil, progname = nil, &block)
          add(#{severity}, message, progname, &block)
        end
       
        def #{severity.downcase}?
          #{severity} >= @level
        end
      EOT
    end
    
  end
end
