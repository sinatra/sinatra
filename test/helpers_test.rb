require File.dirname(__FILE__) + '/helper'

describe 'Sinatra::Helpers' do
  describe '#status' do
    setup do
      mock_app {
        get '/' do
          status 207
          nil
        end
      }
    end

    it 'sets the response status code' do
      get '/'
      response.status.should.equal 207
    end
  end

  describe '#body' do
    it 'takes a block for defered body generation' do
      mock_app {
        get '/' do
          body { 'Hello World' }
        end
      }

      get '/'
      body.should.equal 'Hello World'
    end

    it 'takes a String, Array, or other object responding to #each' do
      mock_app {
        get '/' do
          body 'Hello World'
        end
      }

      get '/'
      body.should.equal 'Hello World'
    end
  end

  describe '#redirect' do
    it 'uses a 302 when only a path is given' do
      mock_app {
        get '/' do
          redirect '/foo'
          fail 'redirect should halt'
        end
      }

      get '/'
      status.should.equal 302
      body.should.be.empty
      response['Location'].should.equal '/foo'
    end

    it 'uses the code given when specified' do
      mock_app {
        get '/' do
          redirect '/foo', 301
          fail 'redirect should halt'
        end
      }

      get '/'
      status.should.equal 301
      body.should.be.empty
      response['Location'].should.equal '/foo'
    end
  end

  describe '#error' do
    it 'sets a status code and halts' do
      mock_app {
        get '/' do
          error 501
          fail 'error should halt'
        end
      }

      get '/'
      status.should.equal 501
      body.should.be.empty
    end

    it 'takes an optional body' do
      mock_app {
        get '/' do
          error 501, 'FAIL'
          fail 'error should halt'
        end
      }

      get '/'
      status.should.equal 501
      body.should.equal 'FAIL'
    end

    it 'uses a 500 status code when first argument is a body' do
      mock_app {
        get '/' do
          error 'FAIL'
          fail 'error should halt'
        end
      }

      get '/'
      status.should.equal 500
      body.should.equal 'FAIL'
    end
  end

  describe '#not_found' do
    it 'halts with a 404 status' do
      mock_app {
        get '/' do
          not_found
          fail 'not_found should halt'
        end
      }

      get '/'
      status.should.equal 404
      body.should.be.empty
    end
  end

  describe '#session' do
    it 'uses the existing rack.session' do
      mock_app {
        get '/' do
          session[:foo]
        end
      }

      get '/', :env => { 'rack.session' => { :foo => 'bar' } }
      body.should.equal 'bar'
    end

    it 'creates a new session when none provided' do
      mock_app {
        get '/' do
          session.should.be.empty
          session[:foo] = 'bar'
          'Hi'
        end
      }

      get '/'
      body.should.equal 'Hi'
    end
  end

  describe '#media_type' do
    include Sinatra::Helpers
    it "looks up media types in Rack's MIME registry" do
      Rack::Mime::MIME_TYPES['.foo'] = 'application/foo'
      media_type('foo').should.equal 'application/foo'
      media_type('.foo').should.equal 'application/foo'
      media_type(:foo).should.equal 'application/foo'
    end
    it 'returns nil when given nil' do
      media_type(nil).should.be.nil
    end
    it 'returns nil when media type not registered' do
      media_type(:bizzle).should.be.nil
    end
    it 'returns the argument when given a media type string' do
      media_type('text/plain').should.equal 'text/plain'
    end
  end

  describe '#content_type' do
    it 'sets the Content-Type header' do
      mock_app {
        get '/' do
          content_type 'text/plain'
          'Hello World'
        end
      }

      get '/'
      response['Content-Type'].should.equal 'text/plain'
      body.should.equal 'Hello World'
    end

    it 'takes media type parameters (like charset=)' do
      mock_app {
        get '/' do
          content_type 'text/html', :charset => 'utf-8'
          "<h1>Hello, World</h1>"
        end
      }

      get '/'
      should.be.ok
      response['Content-Type'].should.equal 'text/html;charset=utf-8'
      body.should.equal "<h1>Hello, World</h1>"
    end

    it "looks up symbols in Rack's mime types dictionary" do
      Rack::Mime::MIME_TYPES['.foo'] = 'application/foo'
      mock_app {
        get '/foo.xml' do
          content_type :foo
          "I AM FOO"
        end
      }

      get '/foo.xml'
      should.be.ok
      response['Content-Type'].should.equal 'application/foo'
      body.should.equal 'I AM FOO'
    end

    it 'fails when no mime type is registered for the argument provided' do
      mock_app {
        get '/foo.xml' do
          content_type :bizzle
          "I AM FOO"
        end
      }

      lambda { get '/foo.xml' }.should.raise RuntimeError
    end
  end

  describe '#send_file' do
    before {
      @file = File.dirname(__FILE__) + '/file.txt'
      File.open(@file, 'wb') { |io| io.write('Hello World') }
    }
    after {
      File.unlink @file
      @file = nil
    }

    def send_file_app
      path = @file
      mock_app {
        get '/file.txt' do
          send_file path
        end
      }
    end

    it "sends the contents of the file" do
      send_file_app
      get '/file.txt'
      should.be.ok
      body.should.equal 'Hello World'
    end

    it 'sets the Content-Type response header if a mime-type can be located' do
      send_file_app
      get '/file.txt'
      response['Content-Type'].should.equal 'text/plain'
    end

    it 'sets the Content-Length response header' do
      send_file_app
      get '/file.txt'
      response['Content-Length'].should.equal 'Hello World'.length.to_s
    end

    it 'sets the Last-Modified response header' do
      send_file_app
      get '/file.txt'
      response['Last-Modified'].should.equal File.mtime(@file).httpdate
    end

    it "returns a 404 when not found" do
      mock_app {
        get '/' do
          send_file 'this-file-does-not-exist.txt'
        end
      }
      get '/'
      should.be.not_found
    end
  end

  describe '#last_modified' do
    before do
      now = Time.now
      mock_app {
        get '/' do
          body { 'Hello World' }
          last_modified now
          'Boo!'
        end
      }
      @now = now
    end

    it 'sets the Last-Modified header to a valid RFC 2616 date value' do
      get '/'
      response['Last-Modified'].should.equal @now.httpdate
    end

    it 'returns a body when conditional get misses' do
      get '/'
      status.should.be 200
      body.should.equal 'Boo!'
    end

    it 'halts when a conditional GET matches' do
      get '/', :env => { 'HTTP_IF_MODIFIED_SINCE' => @now.httpdate }
      status.should.be 304
      body.should.be.empty
    end
  end

  describe '#etag' do
    before do
      mock_app {
        get '/' do
          body { 'Hello World' }
          etag 'FOO'
          'Boo!'
        end
      }
    end

    it 'sets the ETag header' do
      get '/'
      response['ETag'].should.equal '"FOO"'
    end

    it 'returns a body when conditional get misses' do
      get '/'
      status.should.be 200
      body.should.equal 'Boo!'
    end

    it 'halts when a conditional GET matches' do
      get '/', :env => { 'HTTP_IF_NONE_MATCH' => '"FOO"' }
      status.should.be 304
      body.should.be.empty
    end

    it 'should handle multiple ETag values in If-None-Match header' do
      get '/', :env => { 'HTTP_IF_NONE_MATCH' => '"BAR", *' }
      status.should.be 304
      body.should.be.empty
    end

    it 'uses a weak etag with the :weak option' do
      mock_app {
        get '/' do
          etag 'FOO', :weak
          "that's weak, dude."
        end
      }
      get '/'
      response['ETag'].should.equal 'W/"FOO"'
    end

  end
end
