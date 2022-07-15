require 'spec_helper'

RSpec.describe Sinatra::Extension do
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

  it('allows using set') { expect(settings.foo).to eq(:bar) }
  it('implements configure') { expect(settings.reload_stuff).to be false }

  it 'allows defing routes' do
    expect(get('/')).to be_ok
    expect(body).to eq("from extension, yay")
  end
end
