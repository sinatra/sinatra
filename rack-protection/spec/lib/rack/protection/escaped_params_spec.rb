require 'spec_helper'

describe Rack::Protection::EscapedParams do
  it_behaves_like "any rack application"

  context 'escaping' do
    it 'escapes html entities' do
      mock_app do |env|
        request = Rack::Request.new(env)
        [200, {'Content-Type' => 'text/plain'}, [request.params['foo']]]
      end
      get '/', :foo => "<bar>"
      expect(body).to eq('&lt;bar&gt;')
    end

    it 'leaves normal params untouched' do
      mock_app do |env|
        request = Rack::Request.new(env)
        [200, {'Content-Type' => 'text/plain'}, [request.params['foo']]]
      end
      get '/', :foo => "bar"
      expect(body).to eq('bar')
    end

    it 'copes with nested arrays' do
      mock_app do |env|
        request = Rack::Request.new(env)
        [200, {'Content-Type' => 'text/plain'}, [request.params['foo']['bar']]]
      end
      get '/', :foo => {:bar => "<bar>"}
      expect(body).to eq('&lt;bar&gt;')
    end

    it 'leaves cache-breaker params untouched' do
      mock_app do |env|
        [200, {'Content-Type' => 'text/plain'}, ['hi']]
      end

      get '/?95df8d9bf5237ad08df3115ee74dcb10'
      expect(body).to eq('hi')
    end
  end
end
