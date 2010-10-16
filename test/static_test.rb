require File.dirname(__FILE__) + '/helper'

class StaticTest < Test::Unit::TestCase
  setup do
    mock_app {
      set :static, true
      set :public, File.dirname(__FILE__)
    }
  end

  it 'serves GET requests for files in the public directory' do
    get "/#{File.basename(__FILE__)}"
    assert ok?
    assert_equal File.read(__FILE__), body
    assert_equal File.size(__FILE__).to_s, response['Content-Length']
    assert response.headers.include?('Last-Modified')
  end

  it 'produces a body that can be iterated over multiple times' do
    env = Rack::MockRequest.env_for("/#{File.basename(__FILE__)}")
    status, headers, body = @app.call(env)
    buf1, buf2 = [], []
    body.each { |part| buf1 << part }
    body.each { |part| buf2 << part }
    assert_equal buf1.join, buf2.join
    assert_equal File.read(__FILE__), buf1.join
  end

  it 'sets the sinatra.static_file env variable if served' do
    env = Rack::MockRequest.env_for("/#{File.basename(__FILE__)}")
    status, headers, body = @app.call(env)
    assert_equal File.expand_path(__FILE__), env['sinatra.static_file']
  end

  it 'serves HEAD requests for files in the public directory' do
    head "/#{File.basename(__FILE__)}"
    assert ok?
    assert_equal '', body
    assert_equal File.size(__FILE__).to_s, response['Content-Length']
    assert response.headers.include?('Last-Modified')
  end

  %w[POST PUT DELETE].each do |verb|
    it "does not serve #{verb} requests" do
      send verb.downcase, "/#{File.basename(__FILE__)}"
      assert_equal 404, status
    end
  end

  it 'serves files in preference to custom routes' do
    @app.get("/#{File.basename(__FILE__)}") { 'Hello World' }
    get "/#{File.basename(__FILE__)}"
    assert ok?
    assert body != 'Hello World'
  end

  it 'does not serve directories' do
    get "/"
    assert not_found?
  end

  it 'passes to the next handler when the static option is disabled' do
    @app.set :static, false
    get "/#{File.basename(__FILE__)}"
    assert not_found?
  end

  it 'passes to the next handler when the public option is nil' do
    @app.set :public, nil
    get "/#{File.basename(__FILE__)}"
    assert not_found?
  end

  it '404s when a file is not found' do
    get "/foobarbaz.txt"
    assert not_found?
  end

  it 'serves files when .. path traverses within public directory' do
    get "/data/../#{File.basename(__FILE__)}"
    assert ok?
    assert_equal File.read(__FILE__), body
  end

  it '404s when .. path traverses outside of public directory' do
    mock_app {
      set :static, true
      set :public, File.dirname(__FILE__) + '/data'
    }
    get "/../#{File.basename(__FILE__)}"
    assert not_found?
  end

  it 'deals correctly with incompletable range requests' do
    request = Rack::MockRequest.new(@app)
    response = request.get("/#{File.basename(__FILE__)}", 'HTTP_RANGE' => "bytes=45-40")
    
    assert_equal 416,response.status, "Ranges with final position < initial position should give HTTP/1.1 416 Requested Range Not Satisfiable"
  end

  it 'accepts and returns byte ranges correctly' do
    [[[42,88]],[[1,5],[6,85]]].each do |ranges|
      request = Rack::MockRequest.new(@app)
      response = request.get("/#{File.basename(__FILE__)}", 'HTTP_RANGE' => "bytes=#{ranges.map{|r| r.join('-')}.join(',')}")
      
      file = File.read(__FILE__)
      should_be = ''
      ranges.each do |range|
        should_be += file[range[0]..range[1]]
      end
        
      assert_equal 206,response.status, "Should be HTTP/1.1 206 Partial content"
      assert_equal should_be, response.body
      assert_equal should_be.length.to_s, response['Content-Length'], "Length given was not the same as Content-Length reported"
      assert_equal "bytes #{ranges.map{|r| r.join('-')}.join(',')}/#{File.size(__FILE__)}", response['Content-Range'],"Content-Range header was not correct"
    end
  end
end
