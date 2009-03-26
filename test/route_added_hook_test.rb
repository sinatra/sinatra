require File.dirname(__FILE__) + '/helper'

module RouteAddedTest
  @routes = []
  def self.routes ; @routes ; end
  def self.route_added(verb, path)
    @routes << [verb, path]
  end
end

class RouteAddedHookTest < Test::Unit::TestCase
  setup { RouteAddedTest.routes.clear }

  it "should be notified of an added route" do
    mock_app(Class.new(Sinatra::Base)) {
      register RouteAddedTest
      get('/') {}
    }

    assert_equal [["GET", "/"], ["HEAD", "/"]],
      RouteAddedTest.routes
  end

  it "should include hooks from superclass" do
    a = Class.new(Class.new(Sinatra::Base))
    b = Class.new(a)

    a.register RouteAddedTest
    b.class_eval { post("/sub_app_route") {} }

    assert_equal [["POST", "/sub_app_route"]],
      RouteAddedTest.routes
  end

  it "should only run once per extension" do
    mock_app(Class.new(Sinatra::Base)) {
      register RouteAddedTest
      register RouteAddedTest
      get('/') {}
    }

    assert_equal [["GET", "/"], ["HEAD", "/"]],
      RouteAddedTest.routes
  end
end
