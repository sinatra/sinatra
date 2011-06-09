# Tests to check if all the README examples work.
require File.expand_path('../helper', __FILE__)

class ReadmeTest < Test::Unit::TestCase
  example do
    mock_app { get('/') { 'Hello world!' } }
    get '/'
    assert_body 'Hello world!'
  end

  section "Routes" do
    example do
      mock_app do
        get '/' do
          ".. show something .."
        end

        post '/' do
          ".. create something .."
        end

        put '/' do
          ".. replace something .."
        end

        patch '/' do
          ".. modify something .."
        end

        delete '/' do
          ".. annihilate something .."
        end

        options '/' do
          ".. appease something .."
        end
      end

      get '/'
      assert_body '.. show something ..'

      post '/'
      assert_body '.. create something ..'

      put '/'
      assert_body '.. replace something ..'

      patch '/'
      assert_body '.. modify something ..'

      delete '/'
      assert_body '.. annihilate something ..'

      options '/'
      assert_body '.. appease something ..'
    end

    example do
      mock_app do
        get '/hello/:name' do
          # matches "GET /hello/foo" and "GET /hello/bar"
          # params[:name] is 'foo' or 'bar'
          "Hello #{params[:name]}!"
        end
      end

      get '/hello/foo'
      assert_body 'Hello foo!'

      get '/hello/bar'
      assert_body 'Hello bar!'
    end

    example do
      mock_app do
        get '/hello/:name' do |n|
          "Hello #{n}!"
        end
      end

      get '/hello/foo'
      assert_body 'Hello foo!'

      get '/hello/bar'
      assert_body 'Hello bar!'
    end

    example do
      mock_app do
        get '/say/*/to/*' do
          # matches /say/hello/to/world
          params[:splat].inspect # => ["hello", "world"]
        end

        get '/download/*.*' do
          # matches /download/path/to/file.xml
          params[:splat].inspect # => ["path/to/file", "xml"]
        end
      end

      get "/say/hello/to/world"
      assert_body '["hello", "world"]'

      get "/download/path/to/file.xml"
      assert_body '["path/to/file", "xml"]'
    end

    example do
      mock_app do
        get %r{/hello/([\w]+)} do
          "Hello, #{params[:captures].first}!"
        end
      end

      get '/hello/foo'
      assert_body 'Hello, foo!'

      get '/hello/bar'
      assert_body 'Hello, bar!'
    end

    example do
      mock_app do
        get %r{/hello/([\w]+)} do |c|
          "Hello, #{c}!"
        end
      end

      get '/hello/foo'
      assert_body 'Hello, foo!'

      get '/hello/bar'
      assert_body 'Hello, bar!'
    end
  end
end
