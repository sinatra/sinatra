require_relative 'test_helper'
require 'stringio'

# Sinatra::ExtendedRack is a deprecated, inert pass-through in Sinatra 5.0. The
# EventMachine/Thin async.callback path it once supported was removed in favour
# of the Rack 3 callable streaming body, so Sinatra no longer installs it by
# default. It survives only so an app that still `use`s it keeps working (with a
# deprecation warning) instead of raising NameError. These tests pin that
# contract: a stock app is silent, a manual use warns and still passes through.
class ExtendedRackTest < Minitest::Test
  def capture_stderr
    original = $stderr
    $stderr  = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = original
  end

  it 'a stock app does not use ExtendedRack and emits no deprecation warning' do
    warnings = capture_stderr do
      app = Class.new(Sinatra::Base) { get('/') { 'ok' } }
      app.prototype # builds the default middleware stack
    end
    refute_match(/ExtendedRack/, warnings,
                 'a stock app must not trigger the ExtendedRack deprecation')
  end

  it 'warns when an app manually uses Sinatra::ExtendedRack' do
    warnings = capture_stderr do
      app = Class.new(Sinatra::Base) do
        use Sinatra::ExtendedRack
        get('/') { 'ok' }
      end
      app.prototype
    end
    assert_match(/ExtendedRack is deprecated/, warnings)
    assert_match(/removed in Sinatra 5\.0/, warnings)
  end

  it 'still passes the request through when manually used' do
    app = Class.new(Sinatra::Base) do
      set :host_authorization, { permitted_hosts: [] }
      use Sinatra::ExtendedRack
      get('/') { 'passed through' }
    end
    session = Rack::Test::Session.new(Rack::MockSession.new(app))
    capture_stderr { session.get('/') }
    assert session.last_response.ok?
    assert_equal 'passed through', session.last_response.body
  end

  it 'reports async? as removed (no longer an async body protocol)' do
    # The async body protocol detection is gone; ExtendedRack is a plain
    # pass-through Struct and must not expose an async? predicate.
    instance = nil
    capture_stderr { instance = Sinatra::ExtendedRack.new(->(_) {}) }
    refute instance.respond_to?(:async?, true),
           'the async body protocol must be fully removed'
  end

  it 'tripwire: remove the deprecated ExtendedRack shim in Sinatra 6.0' do
    # ExtendedRack is an inert, deprecated pass-through kept for one major so
    # apps that still `use` it are not broken without warning. Once the version
    # reaches 6.0, delete the shim, its middleware handling, and this test.
    assert Gem::Version.new(Sinatra::VERSION) < Gem::Version.new('6.0'),
           'Sinatra is now 6.x: remove the deprecated Sinatra::ExtendedRack shim and this tripwire'
  end
end
