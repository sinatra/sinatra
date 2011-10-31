require File.expand_path('../helper', __FILE__)
require 'rbconfig'
require 'open-uri'
require 'timeout'

class IntegrationTest < Test::Unit::TestCase
  it 'starts a top level application' do
    cmd = []
    app_file = File.expand_path('../integration/app.rb', __FILE__)
    if RbConfig.respond_to? :ruby
      cmd << RbConfig.ruby.inspect
    else
      file, dir = RbConfig::CONFIG.values_at('ruby_install_name', 'bindir')
      cmd << File.expand_path(file, dir).inspect
    end
    cmd << "-I" << File.expand_path('../../lib', __FILE__).inspect
    cmd << app_file.inspect
    cmd << "2>&1"
    pipe = IO.popen(cmd.join(" "))
    Timeout.timeout(10) do
      begin
        assert_equal open('http://localhost:4567/app_file').read, app_file
      rescue Errno::ECONNREFUSED
        sleep 0.1
        retry
      end
    end
    Process.kill("TERM", pipe.pid)
  end
end
