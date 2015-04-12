module DummyApp
  def self.call(env)
    Thread.current[:last_env] = env
    body = (env['REQUEST_METHOD'] == 'HEAD' ? '' : 'ok')
    [200, {'Content-Type' => env['wants'] || 'text/plain'}, [body]]
  end
end