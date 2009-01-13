require File.dirname(__FILE__) + '/helper'

describe 'Sinatra' do
  it 'creates a new Sinatra::Base subclass on new' do
    app =
      Sinatra.new do
        get '/' do
          'Hello World'
        end
      end
    app.superclass.should.be Sinatra::Base
  end
end
