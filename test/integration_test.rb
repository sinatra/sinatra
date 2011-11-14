require File.expand_path('../helper', __FILE__)
require 'rbconfig'
require 'open-uri'
require 'timeout'

class IntegrationTest < Test::Unit::TestCase
  def app_file
    File.expand_path('../integration/app.rb', __FILE__)
  end

  def port
    5000 + (Process.pid % 1000)
  end

  def command
    cmd = ['exec']
    if RbConfig.respond_to? :ruby
      cmd << RbConfig.ruby.inspect
    else
      file, dir = RbConfig::CONFIG.values_at('ruby_install_name', 'bindir')
      cmd << File.expand_path(file, dir).inspect
    end
    cmd << "-I" << File.expand_path('../../lib', __FILE__).inspect
    cmd << app_file.inspect << '-p' << port << '2>&1'
    cmd.join(" ")
  end

  def display_output(pipe)
    out = ""
    loop { out <<  pipe.read_nonblock(1) }
  rescue
    $stderr.puts command, out unless out.empty?
  end

  def kill(pid, signal = "TERM")
    Process.kill(signal, pid)
  rescue NotImplementedError
    system "kill -s #{signal} #{pid}"
  end

  def with_server
    pipe = IO.popen(command)
    error = nil
    Timeout.timeout(120) do
      begin
        yield
      rescue Errno::ECONNREFUSED => e
        error = e
        sleep 0.1
        retry
      end
    end
    kill(pipe.pid) if pipe
  rescue Timeout::Error => e
    display_output pipe
    kill(pipe.pid, "KILL") if pipe
    raise error || e
  end

  it 'starts a top level application' do
    with_server do
      assert_equal open("http://127.0.0.1:#{port}/app_file").read, app_file
    end
  end
end
