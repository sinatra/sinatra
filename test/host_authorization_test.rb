require_relative 'helper'

class HostAuthorizationTest < Minitest::Test
  def app
    Sinatra::Application
  end

  def setup
    @app = Sinatra.new do
      set :permitted_hosts, ['example.com', /\.example\.com$/]
      set :host_authorization_reaction, :block

      # Routes and other configurations
    end
  end

  def test_permitted_host
    get '/', {}, { 'HTTP_HOST' => 'example.com' }
    assert_equal 200, last_response.status
  end

  def test_unpermitted_host
    get '/', {}, { 'HTTP_HOST' => 'evil.com' }
    assert_equal 400, last_response.status
    assert_equal 'Bad Request - Host not allowed', last_response.body
  end

  # Additional tests...
end
