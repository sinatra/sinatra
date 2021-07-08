module DummyAppWithRackResponse
  def self.call(env)
    Thread.current[:last_env] = env
    body = (env['REQUEST_METHOD'] == 'HEAD' ? '' : 'ok')
    Rack::Response.new(body, 200, 'Content-Type' => env['wants'] ||'text/plain')
  end
end
