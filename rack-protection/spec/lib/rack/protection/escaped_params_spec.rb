# frozen_string_literal: true

RSpec.describe Rack::Protection::EscapedParams do
  it_behaves_like 'any rack application'

  context 'escaping' do
    it 'escapes html entities' do
      mock_app do |env|
        request = Rack::Request.new(env)
        [200, { 'content-type' => 'text/plain' }, [request.params['foo']]]
      end
      get '/', foo: '<bar>'
      expect(body).to eq('&lt;bar&gt;')
    end

    it 'leaves normal params untouched' do
      mock_app do |env|
        request = Rack::Request.new(env)
        [200, { 'content-type' => 'text/plain' }, [request.params['foo']]]
      end
      get '/', foo: 'bar'
      expect(body).to eq('bar')
    end

    it 'copes with nested arrays' do
      mock_app do |env|
        request = Rack::Request.new(env)
        [200, { 'content-type' => 'text/plain' }, [request.params['foo']['bar']]]
      end
      get '/', foo: { bar: '<bar>' }
      expect(body).to eq('&lt;bar&gt;')
    end

    it 'leaves cache-breaker params untouched' do
      mock_app do |_env|
        [200, { 'content-type' => 'text/plain' }, ['hi']]
      end

      get '/?95df8d9bf5237ad08df3115ee74dcb10'
      expect(body).to eq('hi')
    end

    it 'leaves TempFiles untouched' do
      mock_app do |env|
        request = Rack::Request.new(env)
        [200, { 'content-type' => 'text/plain' }, ["#{request.params['file'][:filename]}\n#{request.params['file'][:tempfile].read}\n#{request.params['other']}"]]
      end

      temp_file = File.open('_escaped_params_tmp_file', 'w')
      begin
        temp_file.write('hello world')
        temp_file.close

        post '/', file: Rack::Test::UploadedFile.new(temp_file.path), other: '<bar>'
        expect(body).to eq("_escaped_params_tmp_file\nhello world\n&lt;bar&gt;")
      ensure
        File.unlink(temp_file.path)
      end
    end
  end
end
