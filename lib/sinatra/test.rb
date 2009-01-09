require 'sinatra/base'
require 'test/unit'

module Sinatra::Test
  include Rack::Utils

  attr_reader :app, :request, :response

  def mock_app(base=Sinatra::Base, &block)
    @app = Sinatra.new(base, &block)
  end

  undef request if method_defined?(:request)

  def request(verb, path, *args)
    fail "@app not set - cannot make request" if @app.nil?
    @request = Rack::MockRequest.new(@app)
    opts, input =
      case args.size
      when 2 # input, env
        input, env = args
        if input.kind_of?(Hash) # params, env
          [env, param_string(input)]
        else
          [env, input]
        end
      when 1 # params
        if (data = args.first).kind_of?(Hash)
          env = (data.delete(:env) || {})
          [env, param_string(data)]
        else
          [{}, data]
        end
      when 0
        [{}, '']
      else
        raise ArgumentError, "zero, one, or two arguments expected"
      end
    opts = rack_opts(opts)
    opts[:input] ||= input
    yield @request if block_given?
    @response = @request.request(verb, path, opts)
  end

  def get(path, *args, &b)  ; request('GET', path, *args, &b) ; end
  def head(path, *args, &b) ; request('HEAD', path, *args, &b) ; end
  def post(path, *args, &b) ; request('POST', path, *args, &b) ; end
  def put(path, *args, &b)  ; request('PUT', path, *args, &b) ; end
  def delete(path, *args, &b) ; request('DELETE', path, *args, &b) ; end

  def follow!
    request 'GET', @response.location
  end

  def should
    @response.should
  end

  def body
    @response.body
  end

  def status
    @response.status
  end

  RACK_OPT_NAMES = {
    :accept => "HTTP_ACCEPT",
    :agent => "HTTP_USER_AGENT",
    :host => "HTTP_HOST",
    :session => "HTTP_COOKIE",
    :cookies => "HTTP_COOKIE",
    :content_type => "CONTENT_TYPE"
  }

  def rack_opts(opts)
    opts.inject({}) do |hash,(key,val)|
      key = RACK_OPT_NAMES[key] || key
      hash[key] = val
      hash
    end
  end

  def env_for(opts={})
    opts = rack_opts(opts)
    Rack::MockRequest.env_for(opts)
  end

  def param_string(hash)
    hash.map { |pair| pair.map{|v|escape(v)}.join('=') }.join('&')
  end

  if defined? Sinatra::Compat
    # Deprecated. Use: "get" instead of "get_it".
    %w(get head post put delete).each do |verb|
      alias_method "#{verb}_it", verb
      remove_method verb
    end

    include Sinatra::Delegator

    # Deprecated. Tests no longer delegate missing methods to the
    # mock response. Use: @response
    def method_missing(name, *args, &block)
      if @response && @response.respond_to?(name)
        @response.send(name, *args, &block)
      else
        super
      end
    end
  end
end
