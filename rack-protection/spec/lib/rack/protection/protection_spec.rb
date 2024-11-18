# frozen_string_literal: true

require 'stringio'

RSpec.describe Rack::Protection do
  it_behaves_like 'any rack application'

  it 'passes on options' do
    mock_app do
      # the :track option is used by session_hijacking
      use Rack::Protection, track: ['HTTP_FOO'], use: [:session_hijacking], except: [:remote_token]
      run proc { |_e| [200, { 'content-type' => 'text/plain' }, ['hi']] }
    end

    session = { foo: :bar }
    get '/', {}, 'rack.session' => session, 'HTTP_ACCEPT_ENCODING' => 'a'
    get '/', {}, 'rack.session' => session, 'HTTP_ACCEPT_ENCODING' => 'b'
    expect(session[:foo]).to eq(:bar)

    get '/', {}, 'rack.session' => session, 'HTTP_FOO' => 'BAR'
    # won't be empty if the remote_token middleware runs after session_hijacking
    # why we run the mock app without remote_token
    expect(session).to be_empty
  end

  it 'passes errors through if :reaction => :report is used' do
    mock_app do
      use Rack::Protection, reaction: :report
      run proc { |e| [200, { 'content-type' => 'text/plain' }, [e['protection.failed'].to_s]] }
    end

    session = { foo: :bar }
    post('/', {}, 'rack.session' => session, 'HTTP_ORIGIN' => 'http://malicious.com')
    expect(last_response).to be_ok
    expect(body).to eq('true')
  end

  describe '#react' do
    it 'prevents attacks and warns about it' do
      io = StringIO.new
      mock_app do
        use Rack::Protection, logger: Logger.new(io)
        run DummyApp
      end
      post('/', {}, 'rack.session' => {}, 'HTTP_ORIGIN' => 'http://malicious.com')
      expect(io.string).to match(/prevented.*Origin/)
    end

    it 'reports attacks if reaction is to report' do
      io = StringIO.new
      mock_app do
        use Rack::Protection, reaction: :report, logger: Logger.new(io)
        run DummyApp
      end
      post('/', {}, 'rack.session' => {}, 'HTTP_ORIGIN' => 'http://malicious.com')
      expect(io.string).to match(/reported.*Origin/)
      expect(io.string).not_to match(/prevented.*Origin/)
    end

    it 'drops the session and warns if reaction is to drop_session' do
      io = StringIO.new
      mock_app do
        use Rack::Protection, reaction: :drop_session, logger: Logger.new(io)
        run DummyApp
      end
      session = { foo: :bar }
      post('/', {}, 'rack.session' => session, 'HTTP_ORIGIN' => 'http://malicious.com')
      expect(io.string).to match(/session dropped by Rack::Protection::HttpOrigin/)
      expect(session).not_to have_key(:foo)
    end

    it 'passes errors to reaction method if specified' do
      io = StringIO.new
      Rack::Protection::Base.send(:define_method, :special) { |*args| io << args.inspect }
      mock_app do
        use Rack::Protection, reaction: :special, logger: Logger.new(io)
        run DummyApp
      end
      post('/', {}, 'rack.session' => {}, 'HTTP_ORIGIN' => 'http://malicious.com')
      expect(io.string).to match(/HTTP_ORIGIN.*malicious.com/)
      expect(io.string).not_to match(/reported|prevented/)
    end
  end

  describe '#html?' do
    context 'given an appropriate content-type header' do
      subject { Rack::Protection::Base.new(nil).html? 'content-type' => 'text/html' }
      it { is_expected.to be_truthy }
    end

    context 'given an appropriate content-type header of text/xml' do
      subject { Rack::Protection::Base.new(nil).html? 'content-type' => 'text/xml' }
      it { is_expected.to be_truthy }
    end

    context 'given an appropriate content-type header of application/xml' do
      subject { Rack::Protection::Base.new(nil).html? 'content-type' => 'application/xml' }
      it { is_expected.to be_truthy }
    end

    context 'given an inappropriate content-type header' do
      subject { Rack::Protection::Base.new(nil).html? 'content-type' => 'image/gif' }
      it { is_expected.to be_falsey }
    end

    context 'given no content-type header' do
      subject { Rack::Protection::Base.new(nil).html?({}) }
      it { is_expected.to be_falsey }
    end
  end

  describe '#instrument' do
    let(:env) { { 'rack.protection.attack' => 'base' } }
    let(:instrumenter) { double('Instrumenter') }

    after do
      app.instrument(env)
    end

    context 'with an instrumenter specified' do
      let(:app) { Rack::Protection::Base.new(nil, instrumenter: instrumenter) }

      it { expect(instrumenter).to receive(:instrument).with('rack.protection', env) }
    end

    context 'with no instrumenter specified' do
      let(:app) { Rack::Protection::Base.new(nil) }

      it { expect(instrumenter).not_to receive(:instrument) }
    end
  end

  describe 'new' do
    it 'should allow disable session protection' do
      mock_app do
        use Rack::Protection, without_session: true
        run DummyApp
      end

      session = { foo: :bar }
      get '/', {}, 'rack.session' => session, 'HTTP_USER_AGENT' => 'a'
      get '/', {}, 'rack.session' => session, 'HTTP_USER_AGENT' => 'b'
      expect(session[:foo]).to eq :bar
    end

    it 'should allow disable CSRF protection' do
      mock_app do
        use Rack::Protection, without_session: true
        run DummyApp
      end

      post('/', {}, 'HTTP_REFERER' => 'http://example.com/foo', 'HTTP_HOST' => 'example.org')
      expect(last_response).to be_ok
    end
  end
end
