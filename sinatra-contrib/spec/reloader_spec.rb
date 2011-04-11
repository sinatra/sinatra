require 'backports'
require_relative 'spec_helper'
require 'fileutils'

describe Sinatra::Reloader do
  def tmp_dir
    File.expand_path('../../tmp', __FILE__)
  end

  def app_file_path
    File.join(tmp_dir, 'app.rb')
  end

  def write_app_file(options={})
    options[:routes] ||= ['get("/foo") { erb :foo }']
    options[:inline_templates] ||= nil

    File.open(app_file_path, 'w') do |f|
      template_path = File.expand_path('../reloader/app.rb.erb', __FILE__)
      template = Tilt.new(template_path, nil, :trim => '<>')
      f.write template.render(Object.new, options)
    end
  end

  def update_app_file(options={})
    original_mtime = File.mtime(app_file_path)
    begin
      write_app_file(options)
      sleep 0.1
    end until original_mtime != File.mtime(app_file_path)
  end

  before(:each) do
    FileUtils.rm_rf(tmp_dir)
    FileUtils.mkdir_p(tmp_dir)
    write_app_file(
      :routes => ['get("/foo") { erb :foo }'],
      :inline_templates => { :foo => 'foo' }
    )
    $LOADED_FEATURES.delete app_file_path
    require app_file_path
    self.app = App
  end

  after(:all) { FileUtils.rm_rf(tmp_dir) }

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

  it "reloads inline templates" do
    update_app_file(
      :routes => ['get("/foo") { erb :foo }'],
      :inline_templates => { :foo => 'bar' }
    )
    get('/foo').body.should == 'bar'
  end
end
