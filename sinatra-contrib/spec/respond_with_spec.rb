require 'multi_json'

require 'spec_helper'
require 'okjson'

RSpec.describe Sinatra::RespondWith do
  def respond_app(&block)
    mock_app do
      set :app_file, __FILE__
      set :views, root + '/respond_with'
      register Sinatra::RespondWith
      class_eval(&block)
    end
  end

  def respond_to(*args, &block)
    respond_app { get('/') { respond_to(*args, &block) } }
  end

  def respond_with(*args, &block)
    respond_app { get('/') { respond_with(*args, &block) } }
  end

  def req(*types)
    path = types.shift if types.first.is_a?(String) && types.first.start_with?('/')
    accept = types.map { |t| Sinatra::Base.mime_type(t).to_s }.join ','
    get (path || '/'), {}, 'HTTP_ACCEPT' => accept
  end

  describe "Helpers#respond_to" do
    it 'allows defining handlers by file extensions' do
      respond_to do |format|
        format.html { "html!" }
        format.json { "json!" }
      end

      expect(req(:html).body).to eq("html!")
      expect(req(:json).body).to eq("json!")
    end

    it 'respects quality' do
      respond_to do |format|
        format.html { "html!" }
        format.json { "json!" }
      end

      expect(req("text/html;q=0.7, application/json;q=0.3").body).to eq("html!")
      expect(req("text/html;q=0.3, application/json;q=0.7").body).to eq("json!")
    end

    it 'allows using mime types' do
      respond_to do |format|
        format.on('text/html') { "html!" }
        format.json { "json!" }
      end

      expect(req(:html).body).to eq("html!")
    end

    it 'allows using wildcards in format matchers' do
      respond_to do |format|
        format.on('text/*') { "text!" }
        format.json { "json!" }
      end

      expect(req(:html).body).to eq("text!")
    end

    it 'allows using catch all wildcards in format matchers' do
      respond_to do |format|
        format.on('*/*') { "anything!" }
        format.json { "json!" }
      end

      expect(req(:html).body).to eq("anything!")
    end

    it 'prefers concret over generic' do
      respond_to do |format|
        format.on('text/*') { "text!" }
        format.on('*/*') { "anything!" }
        format.json { "json!" }
      end

      expect(req(:json).body).to eq("json!")
      expect(req(:html).body).to eq("text!")
    end

    it 'does not set up default handlers' do
      respond_to
      expect(req).not_to be_ok
      expect(status).to eq(500)
      expect(body).to eq("Unknown template engine")
    end
  end

  describe "Helpers#respond_with" do
    describe "matching" do
      it 'allows defining handlers by file extensions' do
        respond_with(:ignore) do |format|
          format.html { "html!" }
          format.json { "json!" }
        end

        expect(req(:html).body).to eq("html!")
        expect(req(:json).body).to eq("json!")
      end

      it 'respects quality' do
        respond_with(:ignore) do |format|
          format.html { "html!" }
          format.json { "json!" }
        end

        expect(req("text/html;q=0.7, application/json;q=0.3").body).to eq("html!")
        expect(req("text/html;q=0.3, application/json;q=0.7").body).to eq("json!")
      end

      it 'allows using mime types' do
        respond_with(:ignore) do |format|
          format.on('text/html') { "html!" }
          format.json { "json!" }
        end

        expect(req(:html).body).to eq("html!")
      end

      it 'allows using wildcards in format matchers' do
        respond_with(:ignore) do |format|
          format.on('text/*') { "text!" }
          format.json { "json!" }
        end

        expect(req(:html).body).to eq("text!")
      end

      it 'allows using catch all wildcards in format matchers' do
        respond_with(:ignore) do |format|
          format.on('*/*') { "anything!" }
          format.json { "json!" }
        end

        expect(req(:html).body).to eq("anything!")
      end

      it 'prefers concret over generic' do
        respond_with(:ignore) do |format|
          format.on('text/*') { "text!" }
          format.on('*/*') { "anything!" }
          format.json { "json!" }
        end

        expect(req(:json).body).to eq("json!")
        expect(req(:html).body).to eq("text!")
      end
    end

    describe "default behavior" do
      it 'converts objects to json out of the box' do
        respond_with 'a' => 'b'
        expect(OkJson.decode(req(:json).body)).to eq({'a' => 'b'})
      end

      it 'handles multiple routes correctly' do
        respond_app do
          get('/') { respond_with 'a' => 'b' }
          get('/:name') { respond_with 'a' => params[:name] }
        end
        expect(OkJson.decode(req('/',  :json).body)).to eq({'a' => 'b'})
        expect(OkJson.decode(req('/b', :json).body)).to eq({'a' => 'b'})
        expect(OkJson.decode(req('/c', :json).body)).to eq({'a' => 'c'})
      end

      it "calls to_EXT if available" do
        respond_with Struct.new(:to_pdf).new("hello")
        expect(req(:pdf).body).to eq("hello")
      end

      it 'results in a 500 if format cannot be produced' do
        respond_with({})
        expect(req(:html)).not_to be_ok
        expect(status).to eq(500)
        expect(body).to eq("Unknown template engine")
      end
    end

    describe 'templates' do
      it 'looks for templates with name.target.engine' do
        respond_with :foo, :name => 'World'
        expect(req(:html)).to be_ok
        expect(body).to eq("Hello World!")
      end

      it 'looks for templates with name.engine for specific engines' do
        respond_with :bar
        expect(req(:html)).to be_ok
        expect(body).to eq("guten Tag!")
      end

      it 'does not use name.engine for engines producing other formats' do
        respond_with :not_html
        expect(req(:html)).not_to be_ok
        expect(status).to eq(500)
        expect(body).to eq("Unknown template engine")
      end

      it 'falls back to #json if no template is found' do
        respond_with :foo, :name => 'World'
        expect(req(:json)).to be_ok
        expect(OkJson.decode(body)).to eq({'name' => 'World'})
      end

      it 'favors templates over #json' do
        respond_with :bar, :name => 'World'
        expect(req(:json)).to be_ok
        expect(body).to eq('json!')
      end

      it 'falls back to to_EXT if no template is found' do
        object = {:name => 'World'}
        def object.to_pdf; "hi" end
        respond_with :foo, object
        expect(req(:pdf)).to be_ok
        expect(body).to eq("hi")
      end

      unless defined? JRUBY_VERSION
        it 'uses yajl for json' do
          respond_with :baz
          expect(req(:json)).to be_ok
          expect(body).to eq("\"yajl!\"")
        end
      end
    end

    describe 'customizing' do
      it 'allows customizing' do
        respond_with(:foo, :name => 'World') { |f| f.html { 'html!' }}
        expect(req(:html)).to be_ok
        expect(body).to eq("html!")
      end

      it 'falls back to default behavior if none matches' do
        respond_with(:foo, :name => 'World') { |f| f.json { 'json!' }}
        expect(req(:html)).to be_ok
        expect(body).to eq("Hello World!")
      end

      it 'favors generic rule over default behavior' do
        respond_with(:foo, :name => 'World') { |f| f.on('*/*') { 'generic!' }}
        expect(req(:html)).to be_ok
        expect(body).to eq("generic!")
      end
    end

    describe "inherited" do
      it "registers RespondWith in an inherited app" do
        app = Sinatra.new do
          set :app_file, __FILE__
          set :views, root + '/respond_with'
          register Sinatra::RespondWith

          get '/a' do
            respond_with :json
          end
        end

        self.app = Sinatra.new(app)
        expect(req('/a', :json)).not_to be_ok
      end
    end
  end

  describe :respond_to do
    it 'acts as global provides condition' do
      respond_app do
        respond_to :json, :html
        get('/a') { 'ok' }
        get('/b') { 'ok' }
      end

      expect(req('/b', :xml)).not_to be_ok
      expect(req('/b', :html)).to be_ok
    end

    it 'still allows provides' do
      respond_app do
        respond_to :json, :html
        get('/a') { 'ok' }
        get('/b', :provides => :json) { 'ok' }
      end

      expect(req('/b', :html)).not_to be_ok
      expect(req('/b', :json)).to be_ok
    end

    it 'plays well with namespaces' do
      respond_app do
        register Sinatra::Namespace
        namespace '/a' do
          respond_to :json
          get { 'json' }
        end
        get('/b') { 'anything' }
      end

      expect(req('/a', :html)).not_to be_ok
      expect(req('/b', :html)).to be_ok
    end
  end
end
