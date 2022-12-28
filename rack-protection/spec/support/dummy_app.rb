# frozen_string_literal: true

module DummyApp
  def self.call(env)
    Thread.current[:last_env] = env
    body = (env['REQUEST_METHOD'] == 'HEAD' ? '' : 'ok')
    [200, { 'content-type' => env['wants'] || 'text/plain' }, [body]]
  end
end
