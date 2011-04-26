require 'backports'
require_relative 'spec_helper'
require 'fileutils'

describe Sinatra::Reloader do
  # Returns the temporary directory.
  def tmp_dir
    File.expand_path('../../tmp', __FILE__)
  end

  # Returns the path of the Sinatra application file created by
  # +setup_example_app+.
  def app_file_path
    File.join(tmp_dir, "example_app_#{@@example_app_counter}.rb")
  end

  # Returns the name of the Sinatra application created by
  # +setup_example_app+: 'ExampleApp1' for the first application,
  # 'ExampleApp2' fo the second one, and so on...
  def app_name
    "ExampleApp#{@@example_app_counter}"
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
    options[:name] ||= app_name

    update_file(app_file_path) do |f|
      template_path = File.expand_path('../reloader/app.rb.erb', __FILE__)
      template = Tilt.new(template_path, nil, :trim => '<>')
      f.write template.render(Object.new, options)
    end
  end

  alias update_app_file write_app_file

  # It calls <tt>File.open(path, 'w', &block)</tt> all the times
  # needed to change the file's mtime.
  def update_file(path, &block)
    original_mtime = File.exist?(path) ? File.mtime(path) : Time.at(0)
    begin
      File.open(path, 'w', &block)
      sleep 0.1
    end until original_mtime != File.mtime(path)
  end

  # Writes a Sinatra application to a file, requires the file, sets
  # the new application as the one being tested and enables the
  # reloader.
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
      get('/foo').body.strip.should == 'foo'
    end

    it "knows when a route has been modified" do
      update_app_file(:routes => ['get("/foo") { "bar" }'])
      get('/foo').body.strip.should == 'bar'
    end

    it "knows when a route has been added" do
      update_app_file(
        :routes => ['get("/foo") { "foo" }', 'get("/bar") { "bar" }']
      )
      get('/foo').body.strip.should == 'foo'
      get('/bar').body.strip.should == 'bar'
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
      get('/foo').body.strip.should == 'bar'
    end

    it "reloads inline templates in other file" do
      setup_example_app(:routes => ['get("/foo") { erb :foo }'])
      template_file_path = File.join(tmp_dir, 'templates.rb')
      File.open(template_file_path, 'w') do |f|
        f.write "__END__\n\n@@foo\nfoo"
      end
      require template_file_path
      app_const.inline_templates= template_file_path
      get('/foo').body.strip.should == 'foo'
      update_file(template_file_path) do |f|
        f.write "__END__\n\n@@foo\nbar"
      end
      get('/foo').body.strip.should == 'bar'
    end

    it "doesn't try to reload a removed file" do
      update_app_file(:routes => ['get("/foo") { "i shall not be reloaded" }'])
      FileUtils.rm app_file_path
      get('/foo').body.strip.should == 'foo'
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
      get('/foo').body.strip.should == 'foo'
    end

    it "allows to specify a glob to stop matching files from being reloaded" do
      app_const.dont_reload '**/*.rb'
      update_app_file(:routes => ['get("/foo") { "bar" }'])
      get('/foo').body.strip.should == 'foo'
    end

    it "doesn't interfere with other application's reloading policy" do
      app_const.dont_reload '**/*.rb'
      setup_example_app(:routes => ['get("/foo") { "foo" }'])
      update_app_file(:routes => ['get("/foo") { "bar" }'])
      get('/foo').body.strip.should == 'bar'
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
      get('/foo').body.strip.should == 'foo'
      update_file(@foo_path) do |f|
        f.write 'class Foo; def self.foo() "bar" end end'
      end
      get('/foo').body.strip.should == 'bar'
    end

    it "allows to specify glob to reaload matching files" do
      get('/foo').body.strip.should == 'foo'
      update_file(@foo_path) do |f|
        f.write 'class Foo; def self.foo() "bar" end end'
      end
      get('/foo').body.strip.should == 'bar'
    end

    it "doesn't try to reload a removed file" do
      update_file(@foo_path) do |f|
        f.write 'class Foo; def self.foo() "bar" end end'
      end
      FileUtils.rm @foo_path
      get('/foo').body.strip.should == 'foo'
    end

    it "doesn't interfere with other application's reloading policy" do
      app_const.also_reload '**/*.rb'
      setup_example_app(:routes => ['get("/foo") { Foo.foo }'])
      get('/foo').body.strip.should == 'foo'
      update_file(@foo_path) do |f|
        f.write 'class Foo; def self.foo() "bar" end end'
      end
      get('/foo').body.strip.should == 'foo'
    end
  end
end
