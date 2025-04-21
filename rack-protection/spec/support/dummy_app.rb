# frozen_string_literal: true

module DummyApp
  def self.call(env)
    Thread.current[:last_env] = env
    body = (env['REQUEST_METHOD'] == 'HEAD' ? '' : 'ok')

    if Rack::RELEASE >= '3.0'
      headers = { 'content-type' => env['wants'] || 'text/plain' }
    else
      headers = { 'Content-Type' => env['wants'] || 'text/plain' }
    end

    [200, headers, [body]]
  end
end
