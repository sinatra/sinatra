require 'test/unit'
require File.dirname(__FILE__) + "/test/methods"

Test::Unit::TestCase.send :include, Sinatra::Test::Methods
    
Sinatra.default_config[:raise_errors] = true
