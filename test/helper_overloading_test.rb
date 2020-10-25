require File.expand_path('helper', __dir__)
require 'sinatra/base'

class HelpersOverloadingTest < Minitest::Test
  module BaseHelper
    def my_test
      'BaseHelper#test'
    end
  end

  class IncludeAndOverride < Sinatra::Base
    helpers BaseHelper

    get '/' do
      my_test
    end

    helpers do
      def my_test
        'InlineHelper#test'
      end
    end
  end

  it 'uses overloaded inline helper' do
    mock_app(IncludeAndOverride)
    get '/'
    assert ok?
    assert_equal 'InlineHelper#test', body
  end
end
