require 'test/unit'

def silence_warnings
  old_verbose, $VERBOSE = $VERBOSE, nil
  yield
ensure
  $VERBOSE = old_verbose
end

silence_warnings do
  require File.dirname(__FILE__) + '/../sinatra'
end

require File.dirname(__FILE__) + "/test/methods"

Test::Unit::TestCase.send :include, Sinatra::Test::Methods

Sinatra.default_config[:raise_errors] = true
Sinatra.default_config[:env] = :test
Sinatra.default_config[:run] = false

Sinatra.config = nil

Sinatra.setup_logger
