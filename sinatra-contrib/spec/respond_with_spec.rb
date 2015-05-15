require 'multi_json'

require 'spec_helper'
require 'okjson'

describe Sinatra::RespondWith do
  def provides(*args)
    @provides = args
  end

  def respond_app(&block)
    types = @provides
    mock_app do
      set :app_file, __FILE__
      set :views, root + '/respond_with'
      register Sinatra::RespondWith
      respond_to(*types) if types
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
    p = types.shift if types.first.is_a? String and types.first.start_with? '/'
    accept = types.map { |t| Sinatra::Base.mime_type(t).to_s }.join ','
    get (p || '/'), {}, 'HTTP_ACCEPT' => accept
  end

  describe "Helpers#respond_to" do
    it 'allows defining handlers by file extensions' do
      respond_to do |format|
        format.html { "html!" }
        format.json { "json!" }
      end

      req(:html).body.should == "html!"
      req(:json).body.should == "json!"
    end

    it 'respects quality' do
      respond_to do |format|
        format.html { "html!" }
        format.json { "json!" }
      end

      req("text/html;q=0.7, application/json;q=0.3").body.should == "html!"
      req("text/html;q=0.3, application/json;q=0.7").body.should == "json!"
    end

    it 'allows using mime types' do
      respond_to do |format|
        format.on('text/html') { "html!" }
        format.json { "json!" }
      end

      req(:html).body.should == "html!"
    end

    it 'allows using wildcards in format matchers' do
      respond_to do |format|
        format.on('text/*') { "text!" }
        format.json { "json!" }
      end

      req(:html).body.should == "text!"
    end

    it 'allows using catch all wildcards in format matchers' do
      respond_to do |format|
        format.on('*/*') { "anything!" }
        format.json { "json!" }
      end

      req(:html).body.should == "anything!"
    end

    it 'prefers concret over generic' do
      respond_to do |format|
        format.on('text/*') { "text!" }
        format.on('*/*') { "anything!" }
        format.json { "json!" }
      end

      req(:json).body.should == "json!"
      req(:html).body.should == "text!"
    end

    it 'does not set up default handlers' do
      respond_to
      req.should_not be_ok
      status.should == 406
    end
  end

  describe "Helpers#respond_with" do
    describe "matching" do
      it 'allows defining handlers by file extensions' do
        respond_with(:ignore) do |format|
          format.html { "html!" }
          format.json { "json!" }
        end

        req(:html).body.should == "html!"
        req(:json).body.should == "json!"
      end

      it 'respects quality' do
        respond_with(:ignore) do |format|
          format.html { "html!" }
          format.json { "json!" }
        end

        req("text/html;q=0.7, application/json;q=0.3").body.should == "html!"
        req("text/html;q=0.3, application/json;q=0.7").body.should == "json!"
      end

      it 'allows using mime types' do
        respond_with(:ignore) do |format|
          format.on('text/html') { "html!" }
          format.json { "json!" }
        end

        req(:html).body.should == "html!"
      end

      it 'allows using wildcards in format matchers' do
        respond_with(:ignore) do |format|
          format.on('text/*') { "text!" }
          format.json { "json!" }
        end

        req(:html).body.should == "text!"
      end

      it 'allows using catch all wildcards in format matchers' do
        respond_with(:ignore) do |format|
          format.on('*/*') { "anything!" }
          format.json { "json!" }
        end

        req(:html).body.should == "anything!"
      end

      it 'prefers concret over generic' do
        respond_with(:ignore) do |format|
          format.on('text/*') { "text!" }
          format.on('*/*') { "anything!" }
          format.json { "json!" }
        end

        req(:json).body.should == "json!"
        req(:html).body.should == "text!"
      end
    end

    describe "default behavior" do
      it 'converts objects to json out of the box' do
        respond_with 'a' => 'b'
        OkJson.decode(req(:json).body).should == {'a' => 'b'}
      end

      it 'handles multiple routes correctly' do
        respond_app do
          get('/') { respond_with 'a' => 'b' }
          get('/:name') { respond_with 'a' => params[:name] }
        end
        OkJson.decode(req('/',  :json).body).should == {'a' => 'b'}
        OkJson.decode(req('/b', :json).body).should == {'a' => 'b'}
        OkJson.decode(req('/c', :json).body).should == {'a' => 'c'}
      end

      it "calls to_EXT if available" do
        respond_with Struct.new(:to_pdf).new("hello")
        req(:pdf).body.should == "hello"
      end

      it 'results in a 406 if format cannot be produced' do
        respond_with({})
        req(:html).should_not be_ok
        status.should == 406
      end
    end

    describe 'templates' do
      it 'looks for templates with name.target.engine' do
        respond_with :foo, :name => 'World'
        req(:html).should be_ok
        body.should == "Hello World!"
      end

      it 'looks for templates with name.engine for specific engines' do
        respond_with :bar
        req(:html).should be_ok
        body.should == "guten Tag!"
      end

      it 'does not use name.engine for engines producing other formats' do
        respond_with :not_html
        req(:html).should_not be_ok
        status.should == 406
        body.should be_empty
      end

      it 'falls back to #json if no template is found' do
        respond_with :foo, :name => 'World'
        req(:json).should be_ok
        OkJson.decode(body).should == {'name' => 'World'}
      end

      it 'favors templates over #json' do
        respond_with :bar, :name => 'World'
        req(:json).should be_ok
        body.should == 'json!'
      end

      it 'falls back to to_EXT if no template is found' do
        object = {:name => 'World'}
        def object.to_pdf; "hi" end
        respond_with :foo, object
        req(:pdf).should be_ok
        body.should == "hi"
      end

      unless defined? JRUBY_VERSION
        it 'uses yajl for json' do
          respond_with :baz
          req(:json).should be_ok
          body.should == "\"yajl!\""
        end
      end
    end

    describe 'customizing' do
      it 'allows customizing' do
        respond_with(:foo, :name => 'World') { |f| f.html { 'html!' }}
        req(:html).should be_ok
        body.should == "html!"
      end

      it 'falls back to default behavior if none matches' do
        respond_with(:foo, :name => 'World') { |f| f.json { 'json!' }}
        req(:html).should be_ok
        body.should == "Hello World!"
      end

      it 'favors generic rule over default behavior' do
        respond_with(:foo, :name => 'World') { |f| f.on('*/*') { 'generic!' }}
        req(:html).should be_ok
        body.should == "generic!"
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
        req('/a', :json).should_not be_ok
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

      req('/b', :xml).should_not be_ok
      req('/b', :html).should be_ok
    end

    it 'still allows provides' do
      respond_app do
        respond_to :json, :html
        get('/a') { 'ok' }
        get('/b', :provides => :json) { 'ok' }
      end

      req('/b', :html).should_not be_ok
      req('/b', :json).should be_ok
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

      req('/a', :html).should_not be_ok
      req('/b', :html).should be_ok
    end
  end
end
