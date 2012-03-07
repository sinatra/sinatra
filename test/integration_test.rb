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
    cmd << app_file.inspect << '-o' << '127.0.0.1' << '-p' << port << '2>&1'
    cmd.join(" ")
  end

  def display_output(pipe)
    out = read_output(pipe)
    $stderr.puts command, out unless out.empty?
  end

  def read_output(pipe)
    out = ""
    loop { out <<  pipe.read_nonblock(1) }
  rescue
    out
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
      rescue Errno::ECONNREFUSED, Errno::ECONNRESET => e
        error = e
        sleep 0.1
        retry
      end
    end

    output = read_output(pipe)
    kill(pipe.pid) if pipe
    output
  rescue Timeout::Error => e
    display_output pipe
    kill(pipe.pid, "KILL") if pipe
    raise error || e
  end

  def get(url)
    open("http://127.0.0.1:#{port}#{url}").read
  end

  def assert_content(url, content)
    with_server { assert_equal get(url), content }
  end

  it('sets the app_file') { assert_content "/app_file", app_file }
  it('only extends main') { assert_content "/mainonly", "true"   }

  it 'logs once in development mode' do
    log = with_server { get('/app_file') }
    assert_equal 1, log.scan('/app_file').count
  end
end
