require 'sinatra/base'
require 'open-uri'
require 'net/http'

module IntegrationHelper
  class BaseServer
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
      kill
      @log     = ""
      info "running: #{command}"
      @pipe    = IO.popen(command)
      @started = Time.now
      warn "#{server} up and running on port #{port}" if ping
      at_exit { kill }
    end

    def expect(str)
      return if log.size < str.size or log[0, str.size] == str
      raise "Server did not start properly:\n\n#{log}"
    end

    def ping(timeout = 15)
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
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET, EOFError, SystemCallError => error
      false
    end

    def get_stream(url = "/stream", &block)
      Net::HTTP.start '127.0.0.1', port do |http|
        request = Net::HTTP::Get.new url
        http.request request do |response|
          response.read_body(&block)
        end
      end
    end

    def get(url)
      open("http://127.0.0.1:#{port}#{url}").read
    end

    def log
      File.read('log/app.log') rescue ""
    end

    def err
      @err ||= ""
      loop { @err << @pipe.read_nonblock(1) }
    rescue Exception
      @err
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
        cmd = [ 'bundle exec ruby' ] + command_args
        cmd << '2>&1'
        cmd.join(" ")
      end
      @command
    end
    
    def command_args
      [ app_file.inspect ] << 
        '-s' << server << 
        '-o' << '127.0.0.1' << 
        '-p' << port.to_s << 
        '-e' << environment.to_s
    end
    
    def kill
      return unless pipe
      info "killing: #{pipe.pid}"
      if defined?(JRUBY_VERSION)
        `kill -INT #{pipe.pid}`
      else
        Process.kill("KILL", pipe.pid)
      end
    rescue NotImplementedError
      system "kill -9 #{pipe.pid}"
    rescue Errno::ESRCH
    end

    def webrick?
      name.to_s == "webrick"
    end
    
    private

      SILENCE = false

      def info(msg)
        puts msg unless SILENCE
      end
    
  end

  if RUBY_ENGINE == "jruby"
    class JRubyServer < BaseServer

      def run
        return unless installed?
        kill
        @thread  = start_vm
        @started = Time.now
        warn "#{server} up and running on port #{port}" if ping
        at_exit { kill }
      end

      def err
        @out.toString
      end

      def kill
        @thread.kill if @thread
        @thread = nil
      end
      
      private
      
      def start_vm
        require 'java'
        # Create a new container, set load paths and env
        # SINGLETHREAD means create a new runtime
        vm = org.jruby.embed.ScriptingContainer.new(org.jruby.embed.LocalContextScope::SINGLETHREAD)
        
        # This ensures processing of RUBYOPT which activates Bundler
        vm.provider.ruby_instance_config.process_arguments []
        vm.run_scriptlet "require 'rubygems'; require 'bundler'"
        vm.run_scriptlet "Bundler.load.setup_environment" # bundle exec
        
        vm.argv = command_args # TODO does not set ARGV ?!
        vm.run_scriptlet "ARGV.replace #{command_args.inspect}"
        
        @out = java.io.StringWriter.new
        vm.writer = vm.error_writer = @out # $stdout and $stderr
        
        Thread.new do
          # Hack to ensure that Kernel#caller has the same info as
          # when run from command-line, for Sintra::Application.app_file.
          # Also, line numbers are zero-based in JRuby's parser
          vm.provider.runtime.current_context.set_file_and_line(app_file, 0)
          # Run the app
          vm.run_scriptlet org.jruby.embed.PathType::ABSOLUTE, app_file
          # terminate launches at_exit hooks which start server
          vm.terminate
        end
      end
      
    end
    Server = JRubyServer
  else
    Server = BaseServer
  end

  def it(message, &block)
    Server.each do |server|
      next unless server.installed?
      super "with #{server.name}: #{message}" do
        self.server = server
        server.run unless server.alive?
        begin
          instance_eval(&block)
        rescue => error
          server.kill
          raise error
        end
      end
    end
  end

  def self.extend_object(obj)
    super
    
    Sinatra::Base.server.each_with_index do |server, index|
      Server.run(server, 5000 + index)
    end
  end
  
end
