require 'spec_helper'
require 'fileutils'

RSpec.describe Sinatra::Reloader do
  # Returns the temporary directory.
  def tmp_dir
    File.expand_path('../tmp', __dir__)
  end

  # Returns the path of the Sinatra application file created by
  # +setup_example_app+.
  def app_file_path
    File.join(tmp_dir, "example_app_#{$example_app_counter}.rb")
  end

  # Returns the name of the Sinatra application created by
  # +setup_example_app+: 'ExampleApp1' for the first application,
  # 'ExampleApp2' fo the second one, and so on...
  def app_name
    "ExampleApp#{$example_app_counter}"
  end

  # Returns the (constant of the) Sinatra application created by
  # +setup_example_app+.
  def app_const
    Module.const_get(app_name)
  end

  # Writes a file with a Sinatra application using the template
  # located at <tt>specs/reloader/app.rb.erb</tt>.  It expects an
  # +options+ hash, with an array of strings containing the
  # application's routes (+:routes+ key), a hash with the inline
  # template's names as keys and the bodys as values
  # (+:inline_templates+ key) and an optional application name
  # (+:name+) otherwise +app_name+ is used.
  #
  # It ensures to change the written file's mtime when it already
  # exists.
  def write_app_file(options={})
    options[:routes] ||= ['get("/foo") { erb :foo }']
    options[:inline_templates] ||= nil
    options[:extensions] ||= []
    options[:middlewares] ||= []
    options[:filters] ||= []
    options[:errors] ||= {}
    options[:name] ||= app_name
    options[:enable_reloader] = true unless options[:enable_reloader] === false
    options[:parent] ||= 'Sinatra::Base'

    update_file(app_file_path) do |f|
      template_path = File.expand_path('reloader/app.rb.erb', __dir__)
      template = Tilt.new(template_path, nil, :trim => '<>')
      f.write template.render(Object.new, options)
    end
  end

  alias update_app_file write_app_file

  # It calls <tt>File.open(path, 'w', &block)</tt> all the times
  # needed to change the file's mtime.
  def update_file(path, &block)
    original_mtime = File.exist?(path) ? File.mtime(path) : Time.at(0)
    new_time = original_mtime + 1
    File.open(path, 'w', &block)
    File.utime(new_time, new_time, path)
  end

  # Writes a Sinatra application to a file, requires the file, sets
  # the new application as the one being tested and enables the
  # reloader.
  def setup_example_app(options={})
    $example_app_counter ||= 0
    $example_app_counter += 1

    FileUtils.mkdir_p(tmp_dir)
    write_app_file(options)
    $LOADED_FEATURES.delete app_file_path
    require app_file_path
    self.app = app_const
    app_const.enable :reloader
  end

  after(:all) { FileUtils.rm_rf(tmp_dir) }

  describe "default route reloading mechanism" do
    before(:each) do
      setup_example_app(:routes => ['get("/foo") { "foo" }'])
    end

    it "doesn't mess up the application" do
      expect(get('/foo').body).to eq('foo')
    end

    it "knows when a route has been modified" do
      update_app_file(:routes => ['get("/foo") { "bar" }'])
      expect(get('/foo').body).to eq('bar')
    end

    it "knows when a route has been added" do
      update_app_file(
        :routes => ['get("/foo") { "foo" }', 'get("/bar") { "bar" }']
      )
      expect(get('/foo').body).to eq('foo')
      expect(get('/bar').body).to eq('bar')
    end

    it "knows when a route has been removed" do
      update_app_file(:routes => ['get("/bar") { "bar" }'])
      expect(get('/foo').status).to eq(404)
    end

    it "doesn't try to reload a removed file" do
      update_app_file(:routes => ['get("/foo") { "i shall not be reloaded" }'])
      FileUtils.rm app_file_path
      expect(get('/foo').body.strip).to eq('foo')
    end
  end

  describe "default inline templates reloading mechanism" do
    before(:each) do
      setup_example_app(
        :routes => ['get("/foo") { erb :foo }'],
        :inline_templates => { :foo => 'foo' }
      )
    end

    it "doesn't mess up the application" do
      expect(get('/foo').body.strip).to eq('foo')
    end

    it "reloads inline templates in the app file" do
      update_app_file(
        :routes => ['get("/foo") { erb :foo }'],
        :inline_templates => { :foo => 'bar' }
      )
      expect(get('/foo').body.strip).to eq('bar')
    end

    it "reloads inline templates in other file" do
      setup_example_app(:routes => ['get("/foo") { erb :foo }'])
      template_file_path = File.join(tmp_dir, 'templates.rb')
      File.open(template_file_path, 'w') do |f|
        f.write "__END__\n\n@@foo\nfoo"
      end
      require template_file_path
      app_const.inline_templates= template_file_path
      expect(get('/foo').body.strip).to eq('foo')
      update_file(template_file_path) do |f|
        f.write "__END__\n\n@@foo\nbar"
      end
      expect(get('/foo').body.strip).to eq('bar')
    end
  end

  describe "default middleware reloading mechanism" do
    it "knows when a middleware has been added" do
      setup_example_app(:routes => ['get("/foo") { "foo" }'])
      update_app_file(
        :routes => ['get("/foo") { "foo" }'],
        :middlewares => [Rack::Head]
      )
      get('/foo') # ...to perform the reload
      expect(app_const.middleware).not_to be_empty
    end

    it "knows when a middleware has been removed" do
      setup_example_app(
        :routes => ['get("/foo") { "foo" }'],
        :middlewares => [Rack::Head]
      )
      update_app_file(:routes => ['get("/foo") { "foo" }'])
      get('/foo') # ...to perform the reload
      expect(app_const.middleware).to be_empty
    end
  end

  describe "default filter reloading mechanism" do
    it "knows when a before filter has been added" do
      setup_example_app(:routes => ['get("/foo") { "foo" }'])
      expect {
        update_app_file(
          :routes => ['get("/foo") { "foo" }'],
          :filters => ['before { @hi = "hi" }']
        )
        get('/foo') # ...to perform the reload
      }.to change { app_const.filters[:before].size }.by(1)
    end

    it "knows when an after filter has been added" do
      setup_example_app(:routes => ['get("/foo") { "foo" }'])
      expect {
        update_app_file(
          :routes => ['get("/foo") { "foo" }'],
          :filters => ['after { @bye = "bye" }']
        )
        get('/foo') # ...to perform the reload
      }.to change { app_const.filters[:after].size }.by(1)
    end

    it "knows when a before filter has been removed" do
      setup_example_app(
        :routes => ['get("/foo") { "foo" }'],
        :filters => ['before { @hi = "hi" }']
      )
      expect {
        update_app_file(:routes => ['get("/foo") { "foo" }'])
        get('/foo') # ...to perform the reload
      }.to change { app_const.filters[:before].size }.by(-1)
    end

    it "knows when an after filter has been removed" do
      setup_example_app(
        :routes => ['get("/foo") { "foo" }'],
        :filters => ['after { @bye = "bye" }']
      )
      expect {
        update_app_file(:routes => ['get("/foo") { "foo" }'])
        get('/foo') # ...to perform the reload
      }.to change { app_const.filters[:after].size }.by(-1)
    end
  end

  describe "error reloading" do
    before do
      setup_example_app(
        :routes => ['get("/secret") { 403 }'],
        :errors => { 403 => "'Access forbiden'" }
      )
    end

    it "doesn't mess up the application" do
      expect(get('/secret')).to be_client_error
      expect(get('/secret').body.strip).to eq('Access forbiden')
    end

    it "knows when a error has been added" do
      update_app_file(:errors => { 404 => "'Nowhere'" })
      expect(get('/nowhere')).to be_not_found
      expect(get('/nowhere').body).to eq('Nowhere')
    end

    it "knows when a error has been removed" do
      update_app_file(:routes => ['get("/secret") { 403 }'])
      expect(get('/secret')).to be_client_error
      expect(get('/secret').body).not_to eq('Access forbiden')
    end

    it "knows when a error has been modified" do
      update_app_file(
        :routes => ['get("/secret") { 403 }'],
        :errors => { 403 => "'What are you doing here?'" }
      )
      expect(get('/secret')).to be_client_error
      expect(get('/secret').body).to eq('What are you doing here?')
    end
  end

  describe "extension reloading" do
    it "doesn't duplicate routes with every reload" do
      module ::RouteExtension
        def self.registered(klass)
          klass.get('/bar') { 'bar' }
        end
      end

      setup_example_app(
        :routes => ['get("/foo") { "foo" }'],
        :extensions => ['RouteExtension']
      )

      expect {
        update_app_file(
          :routes => ['get("/foo") { "foo" }'],
          :extensions => ['RouteExtension']
        )
        get('/foo') # ...to perform the reload
      }.to_not change { app_const.routes['GET'].size }
    end

    it "doesn't duplicate middleware with every reload" do
      module ::MiddlewareExtension
        def self.registered(klass)
          klass.use Rack::Head
        end
      end

      setup_example_app(
        :routes => ['get("/foo") { "foo" }'],
        :extensions => ['MiddlewareExtension']
      )

      expect {
        update_app_file(
          :routes => ['get("/foo") { "foo" }'],
          :extensions => ['MiddlewareExtension']
        )
        get('/foo') # ...to perform the reload
      }.to_not change { app_const.middleware.size }
    end

    it "doesn't duplicate before filters with every reload" do
      module ::BeforeFilterExtension
        def self.registered(klass)
          klass.before { @hi = 'hi' }
        end
      end

      setup_example_app(
        :routes => ['get("/foo") { "foo" }'],
        :extensions => ['BeforeFilterExtension']
      )

      expect {
        update_app_file(
          :routes => ['get("/foo") { "foo" }'],
          :extensions => ['BeforeFilterExtension']
        )
        get('/foo') # ...to perform the reload
      }.to_not change { app_const.filters[:before].size }
    end

    it "doesn't duplicate after filters with every reload" do
      module ::AfterFilterExtension
        def self.registered(klass)
          klass.after { @bye = 'bye' }
        end
      end

      setup_example_app(
        :routes => ['get("/foo") { "foo" }'],
        :extensions => ['AfterFilterExtension']
      )

      expect {
        update_app_file(
          :routes => ['get("/foo") { "foo" }'],
          :extensions => ['AfterFilterExtension']
        )
        get('/foo') # ...to perform the reload
      }.to_not change { app_const.filters[:after].size }
    end
  end

  describe ".dont_reload" do
    before(:each) do
      setup_example_app(
        :routes => ['get("/foo") { erb :foo }'],
        :inline_templates => { :foo => 'foo' }
      )
    end

    it "allows to specify a file to stop from being reloaded" do
      app_const.dont_reload app_file_path
      update_app_file(:routes => ['get("/foo") { "bar" }'])
      expect(get('/foo').body.strip).to eq('foo')
    end

    it "allows to specify a glob to stop matching files from being reloaded" do
      app_const.dont_reload '**/*.rb'
      update_app_file(:routes => ['get("/foo") { "bar" }'])
      expect(get('/foo').body.strip).to eq('foo')
    end

    it "doesn't interfere with other application's reloading policy" do
      app_const.dont_reload '**/*.rb'
      setup_example_app(:routes => ['get("/foo") { "foo" }'])
      update_app_file(:routes => ['get("/foo") { "bar" }'])
      expect(get('/foo').body.strip).to eq('bar')
    end
  end

  describe ".also_reload" do
    before(:each) do
      setup_example_app(:routes => ['get("/foo") { Foo.foo }'])
      @foo_path = File.join(tmp_dir, 'foo.rb')
      update_file(@foo_path) do |f|
        f.write 'class Foo; def self.foo() "foo" end end'
      end
      $LOADED_FEATURES.delete @foo_path
      require @foo_path
      app_const.also_reload @foo_path
    end

    it "allows to specify a file to be reloaded" do
      expect(get('/foo').body.strip).to eq('foo')
      update_file(@foo_path) do |f|
        f.write 'class Foo; def self.foo() "bar" end end'
      end
      expect(get('/foo').body.strip).to eq('bar')
    end

    it "allows to specify glob to reaload matching files" do
      expect(get('/foo').body.strip).to eq('foo')
      update_file(@foo_path) do |f|
        f.write 'class Foo; def self.foo() "bar" end end'
      end
      expect(get('/foo').body.strip).to eq('bar')
    end

    it "doesn't try to reload a removed file" do
      update_file(@foo_path) do |f|
        f.write 'class Foo; def self.foo() "bar" end end'
      end
      FileUtils.rm @foo_path
      expect(get('/foo').body.strip).to eq('foo')
    end

    it "doesn't interfere with other application's reloading policy" do
      app_const.also_reload '**/*.rb'
      setup_example_app(:routes => ['get("/foo") { Foo.foo }'])
      expect(get('/foo').body.strip).to eq('foo')
      update_file(@foo_path) do |f|
        f.write 'class Foo; def self.foo() "bar" end end'
      end
      expect(get('/foo').body.strip).to eq('foo')
    end
  end

  describe ".after_reload" do
    before(:each) do
      $reloaded = nil
      setup_example_app(:routes => ['get("/foo") { Foo.foo }'])
      @foo_path = File.join(tmp_dir, 'foo.rb')
      update_file(@foo_path) do |f|
        f.write 'class Foo; def self.foo() "foo" end end'
      end
      $LOADED_FEATURES.delete @foo_path
      require @foo_path
      app_const.also_reload @foo_path
    end

    it "allows block execution after reloading files" do
      app_const.after_reload do |files|
        $reloaded = files
      end
      expect($reloaded).to eq(nil)
      expect(get('/foo').body.strip).to eq('foo')
      expect($reloaded).to eq(nil) # after_reload was not called
      update_file(@foo_path) do |f|
        f.write 'class Foo; def self.foo() "bar" end end'
      end
      expect(get("/foo").body.strip).to eq("bar") # Makes the reload happen
      expect($reloaded.size).to eq(1)
      expect(File.basename($reloaded[0])).to eq(File.basename(@foo_path))
    end

    it "does not break block without input param" do
      app_const.after_reload do
        $reloaded = "worked without param"
      end
      expect($reloaded).to eq(nil)
      expect(get('/foo').body.strip).to eq('foo')
      expect($reloaded).to eq(nil) # after_reload was not called
      update_file(@foo_path) do |f|
        f.write 'class Foo; def self.foo() "bar" end end'
      end
      expect { get("/foo") }.to_not raise_error # Makes the reload happen
      expect($reloaded).to eq("worked without param")
    end

    it "handles lambdas with arity 0" do
      user_proc = -> { $reloaded = "lambda?=true arity=0" }
      expect { user_proc.call(1) }.to raise_error(ArgumentError) # What we avoid
      app_const.after_reload(&user_proc)
      expect($reloaded).to eq(nil)
      expect(get('/foo').body.strip).to eq('foo')
      expect($reloaded).to eq(nil) # after_reload was not called
      update_file(@foo_path) do |f|
        f.write 'class Foo; def self.foo() "bar" end end'
      end
      expect { get("/foo") }.to_not raise_error # Makes the reload happen
      expect($reloaded).to eq("lambda?=true arity=0")
    end
  end

  it "automatically registers the reloader in the subclasses" do
    class ::Parent < Sinatra::Base
      register Sinatra::Reloader
      enable :reloader
    end

    setup_example_app(
      :routes => ['get("/foo") { "foo" }'],
      :enable_reloader => false,
      :parent => 'Parent'
    )

    update_app_file(
      :routes => ['get("/foo") { "bar" }'],
      :enable_reloader => false,
      :parent => 'Parent'
    )

    expect(get('/foo').body).to eq('bar')
  end

end
