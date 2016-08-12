if defined? Gem.loaded_specs and Gem.loaded_specs.include? 'rack'
  version = Gem.loaded_specs['rack'].version.to_s
else
  version = Rack.release + '.0'
end

if version == "1.3"
  Rack::Session::Abstract::ID.class_eval do
    private
    def prepare_session(env)
      session_was                  = env[ENV_SESSION_KEY]
      env[ENV_SESSION_KEY]         = SessionHash.new(self, env)
      env[ENV_SESSION_OPTIONS_KEY] = OptionsHash.new(self, env, @default_options)
      env[ENV_SESSION_KEY].merge! session_was if session_was
    end
  end
end

unless Rack::MockResponse.method_defined? :header
  Rack::MockResponse.send(:alias_method, :header, :headers)
end
