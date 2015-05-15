require 'spec_helper'

describe Sinatra::Extension do
  module ExampleExtension
    extend Sinatra::Extension

    set :foo, :bar
    settings.set :bar, :blah

    configure :test, :production do
      set :reload_stuff, false
    end

    configure :development do
      set :reload_stuff, true
    end

    get '/' do
      "from extension, yay"
    end
  end

  before { mock_app { register ExampleExtension }}

  it('allows using set') { settings.foo.should == :bar }
  it('implements configure') { settings.reload_stuff.should be false }

  it 'allows defing routes' do
    get('/').should be_ok
    body.should == "from extension, yay"
  end
end
