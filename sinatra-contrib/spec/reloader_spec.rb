require 'backports'
require_relative 'spec_helper'
require 'fileutils'

describe Sinatra::Reloader do
  def tmp_dir
    File.expand_path('../../tmp', __FILE__)
  end

  def app_file_path
    File.join(tmp_dir, "example_app_#{@@example_app_counter}.rb")
  end

  def app_name
    "ExampleApp#{@@example_app_counter}"
  end

  def app_const
    Module.const_get(app_name)
  end

  def write_app_file(options={})
    options[:routes] ||= ['get("/foo") { erb :foo }']
    options[:inline_templates] ||= nil
    options[:name] ||= app_name

    File.open(app_file_path, 'w') do |f|
      template_path = File.expand_path('../reloader/app.rb.erb', __FILE__)
      template = Tilt.new(template_path, nil, :trim => '<>')
      f.write template.render(Object.new, options)
    end
  end

  def update_app_file(options={})
    update_file(app_file_path) { write_app_file(options) }
  end

  def update_file(path)
    original_mtime = File.mtime(path)
    begin
      yield(path)
      sleep 0.1
    end until original_mtime != File.mtime(path)
  end

  def setup_example_app(options={})
    @@example_app_counter ||= 0
    @@example_app_counter += 1

    FileUtils.mkdir_p(tmp_dir)
    write_app_file(options)
    $LOADED_FEATURES.delete app_file_path
    require app_file_path
    self.app = app_const
    app_const.enable :reloader
  end

  after(:all) { FileUtils.rm_rf(tmp_dir) }

  describe "default reloading mechanism" do
    before(:each) do
      setup_example_app(
        :routes => ['get("/foo") { erb :foo }'],
        :inline_templates => { :foo => 'foo' }
      )
    end

    it "doesn't mess up the application" do
      get('/foo').body.should == 'foo'
    end

    it "knows when a route has been modified" do
      update_app_file(:routes => ['get("/foo") { "bar" }'])
      get('/foo').body.should == 'bar'
    end

    it "knows when a route has been added" do
      update_app_file(
        :routes => ['get("/foo") { "foo" }', 'get("/bar") { "bar" }']
      )
      get('/foo').body.should == 'foo'
      get('/bar').body.should == 'bar'
    end

    it "knows when a route has been removed" do
      update_app_file(:routes => ['get("/bar") { "bar" }'])
      get('/foo').status.should == 404
    end

    it "reloads inline templates in the app file" do
      update_app_file(
        :routes => ['get("/foo") { erb :foo }'],
        :inline_templates => { :foo => 'bar' }
      )
      get('/foo').body.should == 'bar'
    end

    it "reloads inline templates in other file" do
      setup_example_app(:routes => ['get("/foo") { erb :foo }'])
      template_file_path = File.join(tmp_dir, 'templates.rb')
      File.open(template_file_path, 'w') do |f|
        f.write "__END__\n\n@@foo\nfoo"
      end
      require template_file_path
      app_const.inline_templates= template_file_path
      get('/foo').body.should == 'foo'
      update_file(template_file_path) do |path|
        File.open(path, 'w') do |f|
          f.write "__END__\n\n@@foo\nbar"
        end
      end
      get('/foo').body.should == 'bar'
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
      get('/foo').body.should == 'foo'
    end

    it "allows to specify a glob to stop matching files from being reloaded" do
      app_const.dont_reload '**/*.rb'
      update_app_file(:routes => ['get("/foo") { "bar" }'])
      get('/foo').body.should == 'foo'
    end

    it "doesn't interfere with other application's reloading policy" do
      app_const.dont_reload '**/*.rb'
      setup_example_app(:routes => ['get("/foo") { "foo" }'])
      update_app_file(:routes => ['get("/foo") { "bar" }'])
      get('/foo').body.should == 'bar'
    end
  end

  describe ".also_reload" do
    before(:each) do
      setup_example_app(:routes => ['get("/foo") { Foo.foo }'])
      @foo_path = File.join(tmp_dir, 'foo.rb')
      File.open(@foo_path, 'w') do |f|
        f.write 'class Foo; def self.foo() "foo" end end'
      end
      $LOADED_FEATURES.delete @foo_path
      require @foo_path
      app_const.also_reload @foo_path
    end

    it "allows to specify a file to be reloaded" do
      get('/foo').body.should == 'foo'
      update_file(@foo_path) do |path|
        File.open(path, 'w') do |f|
          f.write 'class Foo; def self.foo() "bar" end end'
        end
      end
      get('/foo').body.should == 'bar'
    end

    it "allows to specify glob to reaload matching files" do
      get('/foo').body.should == 'foo'
      update_file(@foo_path) do |path|
        File.open(path, 'w') do |f|
          f.write 'class Foo; def self.foo() "bar" end end'
        end
      end
      get('/foo').body.should == 'bar'
    end

    it "doesn't interfere with other application's reloading policy" do
      app_const.also_reload '**/*.rb'
      setup_example_app(:routes => ['get("/foo") { Foo.foo }'])
      get('/foo').body.should == 'foo'
      update_file(@foo_path) do |path|
        File.open(path, 'w') do |f|
          f.write 'class Foo; def self.foo() "bar" end end'
        end
      end
      get('/foo').body.should == 'foo'
    end
  end
end
