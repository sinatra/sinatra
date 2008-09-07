require File.dirname(__FILE__) + '/unit'
require 'spec/interop/test'

class Test::Unit::TestCase

  def should
    @response.should
  end

end
