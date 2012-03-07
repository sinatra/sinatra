require 'sinatra/base'
require 'rbconfig'
require 'open-uri'

module IntegrationHelper
  class Server
    extend Enumerable
    attr_accessor :server, :port, :pipe
    alias name server

    def self.all
      @all ||= []
    end

    def self.each(&block)
      all.each(&block)
    end

    def self.run(server, port)
      new(server, port).run
    end

    def app_file
      File.expand_path('../integration/app.rb', __FILE__)
    end

    def environment
      "development"
    end

    def initialize(server, port)
      @installed, @pipe, @server, @port = nil, nil, server, port
      Server.all << self
    end

    def run
      return unless installed?
      @log     = ""
      @pipe    = IO.popen(command)
      @started = Time.now
      warn "#{server} up and running on port #{port}" if ping
      at_exit { kill }
    end

    def expect(str)
      return if log.size < str.size or log[0, str.size] == str
      raise "Server did not start properly:\n\n#{log}"
    end

    def ping(timeout = 10)
      loop do
        return if alive?
        if Time.now - @started > timeout
          $stderr.puts command, log
          get('/ping')
        else
          expect "loading"
          sleep 0.1
        end
      end
    end

    def alive?
      3.times { get('/ping') }
      true
    rescue Errno::ECONNREFUSED => error
      false
    end

    def open(url)
      super("http://127.0.0.1:#{port}#{url}")
    end

    def get(url)
      open(url).read
    end

    def log
      @log ||= ""
      loop { @log <<  @pipe.read_nonblock(1) }
    rescue Exception
      @log
    end

    def installed?
      return @installed unless @installed.nil?
      require server
      @installed = true
    rescue LoadError
      warn "#{server} is not installed, skipping integration tests"
      @installed = false
    end

    def command
      @command ||= begin
        cmd = ["RACK_ENV=#{environment}", "exec"]
        if RbConfig.respond_to? :ruby
          cmd << RbConfig.ruby.inspect
        else
          file, dir = RbConfig::CONFIG.values_at('ruby_install_name', 'bindir')
          cmd << File.expand_path(file, dir).inspect
        end
        cmd << "-I" << File.expand_path('../../lib', __FILE__).inspect
        cmd << app_file.inspect << '-s' << server << '-o' << '127.0.0.1' << '-p' << port
        cmd << "-e" << environment.to_s << '2>&1'
        cmd.join " "
      end
    end

    def kill
      return unless pipe
      Process.kill("KILL", pipe.pid)
    rescue NotImplementedError
      system "kill -9 #{pipe.pid}"
    end
  end

  def it(message, &block)
    Server.each do |server|
      next unless server.installed?
      super "with #{server.name}: #{message}" do
        self.server = server
        server.run unless server.alive?
        instance_eval(&block)
      end
    end
  end

  def self.extend_object(obj)
    super

    base_port = 5000 + Process.pid % 100
    Sinatra::Base.server.each_with_index do |server, index|
      Server.run(server, 5000+index)
    end
  end
end
