require_relative 'test_helper'

class ForwardedHostTest < Minitest::Test
  def app
    mock_app do
      get '/' do
        uri('/', true)
      end
    end
  end

  it 'does not trust X-Forwarded-Host header by default' do
    get '/', {}, { 'HTTP_X_FORWARDED_HOST' => 'evil.com' }
    assert_false response.body.include?('evil.com')
  end

  it 'uses X-Forwarded-Host when trust_forwarded_host is enabled' do
    mock_app do
      enable :trust_forwarded_host
      get '/' do
        uri('/', true)
      end
    end

    get '/', {}, { 'HTTP_X_FORWARDED_HOST' => 'trusted.com' }
    assert_include response.body, 'trusted.com'
  end

  it 'ignores X-Forwarded-Host when trust_forwarded_host is disabled' do
    mock_app do
      disable :trust_forwarded_host
      get '/' do
        uri('/', true)
      end
    end

    original_host = 'example.org'
    get '/', {}, { 
      'HTTP_HOST' => original_host,
      'HTTP_X_FORWARDED_HOST' => 'evil.com'
    }
    assert_include response.body, original_host
    assert_false response.body.include?('evil.com')
  end

  it 'handles ports correctly when trust_forwarded_host is enabled' do
    mock_app do
      enable :trust_forwarded_host
      get '/' do
        uri('/', true)
      end
    end

    get '/', {}, { 
      'HTTP_X_FORWARDED_HOST' => 'trusted.com:8080',
      'SERVER_PORT' => '8080'
    }
    assert_include response.body, 'trusted.com:8080'
  end
end
