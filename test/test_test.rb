require File.dirname(__FILE__) + '/../lib/sinatra'
require File.dirname(__FILE__) + '/../lib/sinatra/test'

class TestTest < Test::Unit::TestCase
  
  def test_test
    get_it '/'
    assert_equal 404, status
    assert_equal '<h1>Not Found</h1>', body
  end
    
end
