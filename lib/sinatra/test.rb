require 'test/unit'
require File.dirname(__FILE__) + "/test/methods"

class Test::Unit::TestCase
  include Sinatra::Test::Methods
end

include Sinatra::Test::Methods
    
Sinatra.default_config[:raise_errors] = true
