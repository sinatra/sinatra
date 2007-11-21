require File.dirname(__FILE__) + '/../test'
require "test/spec"

module Sinatra::Test::Methods
  
  def should
    @response.should
  end
  
end
