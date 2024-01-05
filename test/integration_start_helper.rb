require "childprocess"
require "expect"
require "minitest/autorun"

module IntegrationStartHelper
  def command_for(app_file)
    [
      "ruby",
      app_file,
      "-p",
      "0", # any free port
      "-s",
      "puma",
    ]
  end

  def with_process(command:, env: {}, debug: false)
    process = ChildProcess.build(*command)
    process.leader = true # ensure entire process tree dies
    process.environment.merge!(env)
    read_io, write_io = IO.pipe
    process.io.stdout = write_io
    process.io.stderr = write_io
    process.start
    # Close parent's copy of the write end of the pipe so when the (forked) child
    # process closes its write end of the pipe the parent receives EOF when
    # attempting to read from it. If the parent leaves its write end open, it
    # will not detect EOF.
    write_io.close

    echo_output(read_io) if debug || debug_all?

    yield process, read_io
  ensure
    read_io.close
    process.stop
  end

  def echo_output(read_io)
    Thread.new do
      begin
        loop { print read_io.readpartial(8192) }
      rescue EOFError
      end
    end
  end

  def debug_all?
    ENV.key?("DEBUG_START_PROCESS")
  end

  def wait_timeout
    case RUBY_ENGINE
    when "jruby", "truffleruby"
      # takes some time to start the JVM
      10.0
    else
      3.0
    end
  end

  def wait_for_output(read_io, matcher, timeout = wait_timeout)
    return true if read_io.expect(matcher, timeout).to_a.any?

    raise "Waited for #{timeout} seconds, but received no output matching: " \
          "#{matcher.source}"
  end
end
