require 'spec_helper'

describe Sinatra::ConfigFile do
  def config_file(*args, &block)
    mock_app do
      register Sinatra::ConfigFile
      set :root, File.expand_path('../config_file', __FILE__)
      instance_eval(&block) if block
      config_file(*args)
    end
  end

  it 'should set options from a simple config_file' do
    config_file 'key_value.yml'
    settings.foo.should == 'bar'
    settings.something.should == 42
  end

  it 'should create indifferent hashes' do
    config_file 'key_value.yml'
    settings.nested['a'].should == 1
    settings.nested[:a].should == 1
  end

  it 'should render options in ERB tags' do
    config_file 'key_value.yml.erb'
    settings.foo.should == "bar"
    settings.something.should == 42
    settings.nested['a'].should == 1
    settings.nested[:a].should == 1
    settings.nested['b'].should == 2
    settings.nested[:b].should == 2
  end

  it 'should recognize env specific settings per file' do
    config_file 'with_envs.yml'
    settings.foo.should == 'test'
  end

  it 'should recognize env specific settings per setting' do
    config_file 'with_nested_envs.yml'
    settings.database[:adapter].should == 'sqlite'
  end

  it 'should not set present values to nil if the current env is missing' do
    # first let's check the test is actually working properly
    config_file('missing_env.yml') { set :foo => 42, :environment => :production }
    settings.foo.should == 10
    # now test it
    config_file('missing_env.yml') { set :foo => 42, :environment => :test }
    settings.foo.should == 42
  end

  it 'should prioritize settings in latter files' do
    # first let's check the test is actually working properly
    config_file 'key_value.yml'
    settings.foo.should == 'bar'
    # now test it
    config_file 'key_value_override.yml'
    settings.foo.should == 'foo'
  end
end
