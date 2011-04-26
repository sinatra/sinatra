require 'sinatra/base'
require 'forwardable'

module Sinatra
  module CSRF
    SAFE_METHODS = %w[GET HEAD OPTIONS TRACE]
    TOKEN_HEADER = 'HTTP_X_CSRF_Token'
    TOKEN_FIELD  = 'authenticity_token'

    def self.registered(base)
      base.enable :csrf_protection unless base.respond_to? :csrf_protection
      base.helpers Helpers
      base.use Middleware, base
    end

    module Helpers
      def authenticity_token
        session['sinatra.token']
      end

      def authenticity_tag
        return "" unless authenticity_token
        "<input type='hidden' name='#{TOKEN_FIELD}' value='#{authenticity_token}' />"
      end

      alias csrf_token authenticity_token
      alias csrf_tag   authenticity_tag
    end

    class Middleware
      extend Forwardable
      def_delegators :@base, :csrf_protection?, :csrf_protection, :test?, :development?

      def initialize(app, base)
        @app, @base = app, base
      end

      def call(env)
        return @app.call(env) unless csrf_protection
        request = Sinatra::Request.new env
        set_token(request) if checks.include? :token
        safe?(request) ? @app.call(env) : response(request)
      end

      private

      def checks
        return @checks if defined? @checks
        checks = [:verb, Array(*csrf_protection)]
        checks.map! { |c| c == true ? :optional_referrer : c }
        checks.delete :verb if checks.delete :all_verbs
        @checks = checks
      end

      def set_token(request)
        request.session['sinatra.token'] ||= '%x' % rand(2**255)
      end

      def safe?(r)
        checks.any? { |c| send("safe_#{m}?", r) }
      end

      def safe_method?(r)
        SAFE_METHODS.include? r.request_method
      end

      def safe_token?(r)
        token = request.session['sinatra.token']
        r.env[TOKEN_HEADER] == token or r[TOKEN_FIELD] == token
      end

      def safe_forms?(r)
        request.xhr? or safe_token?(r)
      end

      def safe_referrer?(r)
        URI.parse(r.referrer.to_s).host == r.host
      end

      alias safe_referer? safe_referrer?

      def safe_optional_referrer?(r)
        r.referrer.nil? or safe_referrer?(r)
      end

      def response(r)
        fail error if test?
        response = Rack::Response.new
        response.status = 412
        if development?
          response.body << <<-HTML.gsub(/^ {12}/, '')
            <!DOCTYPE html>
            <html>
              <head>
                <style type="text/css">
                  body { text-align:center;font-family:helvetica,arial;font-size:22px;
                    color:#888;margin:20px}
                  #c {margin:0 auto;width:500px;text-align:left}
                </style>
              </head>
              <body>
                <h2>Potentinal CSRF attack prevented!</h2>
                <img src='#{r.script_name}/__sinatra__/500.png'>
                <div id="c">
                  <p>
                    Sinatra automatically blocks unsafe requests coming from other
                    hosts. If you want to allow such requests, please make sure
                    you fully understand how CSRF attacks work first, and then,
                    add the following line to your Sinatra application:
                  </p>
                  <pre>disable :csrf_protection</pre>
                  <p>
                    You can also change the CSRF counter measures like this:
                  </p>
                  <pre>set :csrf_protection, :token</pre>
                </div>
              </body>
            </html>
          HTML
        end
        response.finish
      end
    end
  end

  register CSRF
end
