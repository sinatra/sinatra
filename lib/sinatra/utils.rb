module Sinatra
  # Some Rack handlers (Thin, Rainbows!) implement an extended body object protocol, however,
  # some middleware (namely Rack::Lint) will break it by not mirroring the methods in question.
  # This middleware will detect an extended body object and will make sure it reaches the
  # handler directly. We do this here, so our middleware and middleware set up by the app will
  # still be able to run.
  class ExtendedRack < Struct.new(:app)
    def call(env)
      result, callback = app.call(env), env['async.callback']
      return result unless callback and async?(*result)
      after_response { callback.call result }
      setup_close(env, *result)
      throw :async
    end

    private

    def setup_close(env, status, headers, body)
      return unless body.respond_to? :close and env.include? 'async.close'
      env['async.close'].callback { body.close }
      env['async.close'].errback { body.close }
    end

    def after_response(&block)
      raise NotImplementedError, "only supports EventMachine at the moment" unless defined? EventMachine
      EventMachine.next_tick(&block)
    end

    def async?(status, headers, body)
      return true if status == -1
      body.respond_to? :callback and body.respond_to? :errback
    end
  end

  # Behaves exactly like Rack::CommonLogger with the notable exception that it does nothing,
  # if another CommonLogger is already in the middleware chain.
  class CommonLogger < Rack::CommonLogger
    def call(env)
      env['sinatra.commonlogger'] ? @app.call(env) : super
    end

    superclass.class_eval do
      alias call_without_check call unless method_defined? :call_without_check
      def call(env)
        env['sinatra.commonlogger'] = true
        call_without_check(env)
      end
    end
  end

  class NotFound < NameError #:nodoc:
    def http_status; 404 end
  end
end
