require 'sinatra/base'
require 'rbconfig'
require 'open-uri'
require 'sinatra/runner'

module IntegrationHelper
  class BaseServer < Sinatra::Runner
    extend Enumerable
    attr_accessor :server, :port
    alias name server

    def self.all
      @all ||= []
    end

    def self.all_async
      @all_async ||= []
    end

    def self.each(&block)
      all.each(&block)
    end

    def self.run(server, port, async: false)
      new(server, port, async).run
    end

    def app_file
      File.expand_path('integration/app.rb', __dir__)
    end

    def environment
      "development"
    end

    def initialize(server, port, async)
      @installed, @pipe, @server, @port = nil, nil, server, port
      ENV['PUMA_MIN_THREADS'] = '1' if server == 'puma'
      if async
        Server.all_async << self
      else
        Server.all << self
      end
    end

    def run
      return unless installed?
      kill
      @log     = +""
      super
      at_exit { kill }
    end

    def installed?
      return @installed unless @installed.nil?
      s = server == 'HTTP' ? 'net/http/server' : server
      require s
      @installed = true
    rescue LoadError
      warn "#{server} is not installed, skipping integration tests"
      @installed = false
    end

    def command
      @command ||= begin
        cmd = ["APP_ENV=#{environment}", "exec"]
        if RbConfig.respond_to? :ruby
          cmd << RbConfig.ruby.inspect
        else
          file, dir = RbConfig::CONFIG.values_at('ruby_install_name', 'bindir')
          cmd << File.expand_path(file, dir).inspect
        end
        cmd << "-w" unless net_http_server?
        cmd << "-I" << File.expand_path('../lib', __dir__).inspect
        cmd << app_file.inspect << '-s' << server << '-o' << '127.0.0.1' << '-p' << port
        cmd << "-e" << environment.to_s << '2>&1'
        cmd.join " "
      end
    end

    def webrick?
      name.to_s == "webrick"
    end

    def puma?
      name.to_s == "puma"
    end

    def falcon?
      name.to_s == "falcon"
    end

    def trinidad?
      name.to_s == "trinidad"
    end

    def net_http_server?
      name.to_s == 'HTTP'
    end

    def warnings
      log.scan(%r[(?:\(eval|lib/sinatra).*warning:.*$])
    end

    def run_test(target, &block)
      retries ||= 3
      target.server = self
      run unless alive?
      target.instance_eval(&block)
    rescue Exception => error
      retries -= 1
      kill
      retries < 0 ? retry : raise(error)
    end
  end

  Server = BaseServer

  def it(message, &block)
    Server.each do |server|
      next unless server.installed?
      super("with #{server.name}: #{message}") { server.run_test(self, &block) }
    end
  end

  def self.extend_object(obj)
    super

    base_port = 5000 + Process.pid % 100
    servers = Sinatra::Base.server.dup

    # TruffleRuby doesn't support `Fiber.set_scheduler` yet
    unsupported_truffleruby = RUBY_ENGINE == "truffleruby" && !Fiber.respond_to?(:set_scheduler)
    # Ruby 2.7 uses falcon 0.42.3 which isn't working with rackup 2.2.0+
    too_old_ruby = RUBY_VERSION <= "3.0.0"

    if unsupported_truffleruby || too_old_ruby
      warn "skip falcon server"
      servers.delete('falcon')
    end

    servers.each_with_index do |server, index|
      Server.run(server, base_port+index)
    end
  end
end
