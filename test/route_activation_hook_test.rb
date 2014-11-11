require File.expand_path('../helper', __FILE__)

module RouteActivationTest
  @before_activations, @after_activations = [], []
  def self.before_activations ; @before_activations ; end
  def self.after_activations ; @after_activations ; end
  def self.before_route_activation(app, verb, path, params)
    @before_activations << [app, verb, path, params]
  end
  def self.after_route_activation(app, verb, path, params)
    @after_activations << [app, verb, path, params]
  end
end

class RouteActivationHookTest < Test::Unit::TestCase
  def activation_app
    mock_app(Class.new(Sinatra::Base)) do
      register RouteActivationTest

      get('/:foo') {}
      get('/block/:foo', &proc { |arg1| "custom block #{arg1}" })

      # Added only to verify that they are not decorated with the hooks
      before { @baz = 'pre-baz' }
      after { @baz = 'after-baz' }
    end
  end

  setup do
    RouteActivationTest.before_activations.clear
    RouteActivationTest.after_activations.clear
  end

  it "should be notified when a route without a block is about to be activated" do
    activation_app
    get '/bar'

    before_activations = RouteActivationTest.before_activations
    assert_equal 1, before_activations.size

    activation = before_activations.first
    assert_kind_of Sinatra::Base, activation[0]
    assert_equal 'GET', activation[1]
    assert_equal '/:foo', activation[2]
    assert_equal ['bar'], activation[3]
  end

  it "should be notified after a route without a block has been activated" do
    activation_app
    get '/bar'

    after_activations = RouteActivationTest.after_activations
    assert_equal 1, after_activations.size

    activation = after_activations.first
    assert_kind_of Sinatra::Base, activation[0]
    assert_equal 'GET', activation[1]
    assert_equal '/:foo', activation[2]
    assert_equal ['bar'], activation[3]
  end

  it "should be notified when a route with a block is about to be activated" do
    activation_app
    get '/block/bar'

    before_activations = RouteActivationTest.before_activations
    assert_equal 1, before_activations.size

    activation = before_activations.first
    assert_kind_of Sinatra::Base, activation[0]
    assert_equal 'GET', activation[1]
    assert_equal '/block/:foo', activation[2]
    assert_equal ['bar'], activation[3]
  end

  it "should be notified after a route with a block has been activated" do
    activation_app
    get '/block/bar'

    after_activations = RouteActivationTest.after_activations
    assert_equal 1, after_activations.size

    activation = after_activations.first
    assert_kind_of Sinatra::Base, activation[0]
    assert_equal 'GET', activation[1]
    assert_equal '/block/:foo', activation[2]
    assert_equal ['bar'], activation[3]
  end

  it "should only run once per extension" do
    mock_app(Class.new(Sinatra::Base)) do
      register RouteActivationTest
      register RouteActivationTest
      get('/') {}
    end

    get '/'

    assert_equal 1, RouteActivationTest.before_activations.size
    assert_equal 1, RouteActivationTest.after_activations.size
  end
end
