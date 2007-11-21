require 'test/unit'
require File.dirname(__FILE__) + "/test/methods"

class Test::Unit::TestCase
  include Sinatra::Test::Methods
end
