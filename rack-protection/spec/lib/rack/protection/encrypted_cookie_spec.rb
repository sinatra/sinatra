# frozen_string_literal: true

RSpec.describe Rack::Protection::EncryptedCookie do
  let(:incrementor) do
    lambda do |env|
      env['rack.session']['counter'] ||= 0
      env['rack.session']['counter'] += 1
      hash = env['rack.session'].dup
      hash.delete('session_id')
      Rack::Response.new(hash.inspect).to_a
    end
  end

  let(:session_id) do
    lambda do |env|
      Rack::Response.new(env['rack.session'].to_hash.inspect).to_a
    end
  end

  let(:session_option) do
    lambda do |opt|
      lambda do |env|
        Rack::Response.new(env['rack.session.options'][opt].inspect).to_a
      end
    end
  end

  let(:nothing) do
    lambda do |_env|
      Rack::Response.new('Nothing').to_a
    end
  end

  let(:renewer) do
    lambda do |env|
      env['rack.session.options'][:renew] = true
      Rack::Response.new('Nothing').to_a
    end
  end

  let(:only_session_id) do
    lambda do |env|
      Rack::Response.new(env['rack.session']['session_id'].to_s).to_a
    end
  end

  let(:bigcookie) do
    lambda do |env|
      env['rack.session']['cookie'] = 'big' * 3000
      Rack::Response.new(env['rack.session'].inspect).to_a
    end
  end

  let(:destroy_session) do
    lambda do |env|
      env['rack.session'].destroy
      Rack::Response.new('Nothing').to_a
    end
  end

  def response_for(options = {})
    request_options = options.fetch(:request, {})
    cookie = if options[:cookie].is_a?(Rack::Response)
               options[:cookie]['Set-Cookie']
             else
               options[:cookie]
             end
    request_options['HTTP_COOKIE'] = cookie || ''

    app_with_cookie = Rack::Protection::EncryptedCookie.new(*options[:app])
    app_with_cookie = Rack::Lint.new(app_with_cookie)
    Rack::MockRequest.new(app_with_cookie).get('/', request_options)
  end

  def random_cipher_secret
    OpenSSL::Cipher.new('aes-256-gcm').random_key.unpack1('H*')
  end

  let(:secret) { random_cipher_secret }
  let(:warnings) { [] }

  before do
    local_warnings = warnings

    Rack::Protection::EncryptedCookie.class_eval do
      define_method(:warn) { |m| local_warnings << m }
    end
  end

  after do
    Rack::Protection::EncryptedCookie.class_eval { remove_method :warn }
  end

  describe 'Base64' do
    it 'uses base64 to encode' do
      coder = Rack::Protection::EncryptedCookie::Base64.new
      str   = 'fuuuuu'
      expect(coder.encode(str)).to eq([str].pack('m0'))
    end

    it 'uses base64 to decode' do
      coder = Rack::Protection::EncryptedCookie::Base64.new
      str   = ['fuuuuu'].pack('m0')
      expect(coder.decode(str)).to eq(str.unpack1('m0'))
    end

    it 'handles non-strict base64 encoding' do
      coder = Rack::Protection::EncryptedCookie::Base64.new
      str   = ['A' * 256].pack('m')
      expect(coder.decode(str)).to eq('A' * 256)
    end

    describe 'Marshal' do
      it 'marshals and base64 encodes' do
        coder = Rack::Protection::EncryptedCookie::Base64::Marshal.new
        str   = 'fuuuuu'
        expect(coder.encode(str)).to eq([::Marshal.dump(str)].pack('m0'))
      end

      it 'marshals and base64 decodes' do
        coder = Rack::Protection::EncryptedCookie::Base64::Marshal.new
        str   = [::Marshal.dump('fuuuuu')].pack('m0')
        expect(coder.decode(str)).to eq(::Marshal.load(str.unpack1('m0')))
      end

      it 'rescues failures on decode' do
        coder = Rack::Protection::EncryptedCookie::Base64::Marshal.new
        expect(coder.decode('lulz')).to be_nil
      end
    end

    describe 'JSON' do
      it 'JSON and base64 encodes' do
        coder = Rack::Protection::EncryptedCookie::Base64::JSON.new
        obj   = %w[fuuuuu]
        expect(coder.encode(obj)).to eq([::JSON.dump(obj)].pack('m0'))
      end

      it 'JSON and base64 decodes' do
        coder = Rack::Protection::EncryptedCookie::Base64::JSON.new
        str   = [::JSON.dump(%w[fuuuuu])].pack('m0')
        expect(coder.decode(str)).to eq(::JSON.parse(str.unpack1('m0')))
      end

      it 'rescues failures on decode' do
        coder = Rack::Protection::EncryptedCookie::Base64::JSON.new
        expect(coder.decode('lulz')).to be_nil
      end
    end

    describe 'ZipJSON' do
      it 'jsons, deflates, and base64 encodes' do
        coder = Rack::Protection::EncryptedCookie::Base64::ZipJSON.new
        obj   = %w[fuuuuu]
        json = JSON.dump(obj)
        expect(coder.encode(obj)).to eq([Zlib::Deflate.deflate(json)].pack('m0'))
      end

      it 'base64 decodes, inflates, and decodes json' do
        coder = Rack::Protection::EncryptedCookie::Base64::ZipJSON.new
        obj   = %w[fuuuuu]
        json  = JSON.dump(obj)
        b64   = [Zlib::Deflate.deflate(json)].pack('m0')
        expect(coder.decode(b64)).to eq(obj)
      end

      it 'rescues failures on decode' do
        coder = Rack::Protection::EncryptedCookie::Base64::ZipJSON.new
        expect(coder.decode('lulz')).to be_nil
      end
    end
  end

  it 'warns if no secret is given' do
    Rack::Protection::EncryptedCookie.new(incrementor)
    expect(warnings.first).to match(/no secret/i)
    warnings.clear
    Rack::Protection::EncryptedCookie.new(incrementor, secret: secret)
    expect(warnings).to be_empty
  end

  it 'warns if secret is to short' do
    Rack::Protection::EncryptedCookie.new(incrementor, secret: secret[0, 16])
    expect(warnings.first).to match(/secret is not long enough/i)
    warnings.clear
    Rack::Protection::EncryptedCookie.new(incrementor, secret: secret)
    expect(warnings).to be_empty
  end

  it "doesn't warn if coder is configured to handle encoding" do
    Rack::Protection::EncryptedCookie.new(
      incrementor, coder: Object.new, let_coder_handle_secure_encoding: true
    )
    expect(warnings).to be_empty
  end

  it 'still warns if coder is not set' do
    Rack::Protection::EncryptedCookie.new(
      incrementor,
      let_coder_handle_secure_encoding: true
    )
    expect(warnings.first).to match(/no secret/i)
  end

  it 'uses a coder' do
    identity = Class.new do
      attr_reader :calls

      def initialize
        @calls = []
      end

      def encode(str)
        @calls << :encode
        str
      end

      def decode(str)
        @calls << :decode
        str
      end
    end.new
    response = response_for(app: [incrementor, { coder: identity }])

    expect(response['Set-Cookie']).to include('rack.session=')
    expect(response.body).to eq('{"counter"=>1}')
    expect(identity.calls).to eq(%i[decode encode])
  end

  it 'creates a new cookie' do
    response = response_for(app: incrementor)
    expect(response['Set-Cookie']).to include('rack.session=')
    expect(response.body).to eq('{"counter"=>1}')
  end

  it 'loads from a cookie' do
    response = response_for(app: incrementor)

    response = response_for(app: incrementor, cookie: response)
    expect(response.body).to eq('{"counter"=>2}')

    response = response_for(app: incrementor, cookie: response)
    expect(response.body).to eq('{"counter"=>3}')
  end

  it 'renew session id' do
    response = response_for(app: incrementor)
    cookie   = response['Set-Cookie']
    response = response_for(app: only_session_id, cookie: cookie)
    cookie   = response['Set-Cookie'] if response['Set-Cookie']

    expect(response.body).to_not eq('')
    old_session_id = response.body

    response = response_for(app: renewer, cookie: cookie)
    cookie   = response['Set-Cookie'] if response['Set-Cookie']
    response = response_for(app: only_session_id, cookie: cookie)

    expect(response.body).to_not eq('')
    expect(response.body).to_not eq(old_session_id)
  end

  it 'destroys session' do
    response = response_for(app: incrementor)
    response = response_for(app: only_session_id, cookie: response)

    expect(response.body).to_not eq('')
    old_session_id = response.body

    response = response_for(app: destroy_session, cookie: response)
    response = response_for(app: only_session_id, cookie: response)

    expect(response.body).to_not eq('')
    expect(response.body).to_not eq(old_session_id)
  end

  it 'survives broken cookies' do
    response = response_for(
      app: incrementor,
      cookie: 'rack.session=blarghfasel'
    )
    expect(response.body).to eq('{"counter"=>1}')

    response = response_for(
      app: [incrementor, { secret: secret }],
      cookie: 'rack.session='
    )
    expect(response.body).to eq('{"counter"=>1}')
  end

  it 'barks on too big cookies' do
    expect do
      response_for(app: bigcookie, request: { fatal: true })
    end.to raise_error Rack::MockRequest::FatalWarning
  end

  it 'loads from a cookie with integrity hash' do
    app = [incrementor, { secret: secret }]

    response = response_for(app: app)
    response = response_for(app: app, cookie: response)
    expect(response.body).to eq('{"counter"=>2}')

    response = response_for(app: app, cookie: response)
    expect(response.body).to eq('{"counter"=>3}')

    app = [incrementor, { secret: random_cipher_secret }]

    response = response_for(app: app, cookie: response)
    expect(response.body).to eq('{"counter"=>1}')
  end

  it 'loads from a cookie with accept-only integrity hash for graceful key rotation' do
    response = response_for(app: [incrementor, { secret: secret }])

    new_secret = random_cipher_secret

    app = [incrementor, { secret: new_secret, old_secret: secret }]
    response = response_for(app: app, cookie: response)
    expect(response.body).to eq('{"counter"=>2}')

    newer_secret = random_cipher_secret

    app = [incrementor, { secret: newer_secret, old_secret: new_secret }]
    response = response_for(app: app, cookie: response)
    expect(response.body).to eq('{"counter"=>3}')
  end

  it 'loads from a legacy hmac cookie' do
    legacy_session = Rack::Protection::EncryptedCookie::Base64::Marshal.new.encode({ 'counter' => 1, 'session_id' => 'abcdef' })
    legacy_secret  = 'test legacy secret'
    legacy_digest  = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('SHA1'), legacy_secret, legacy_session)

    legacy_cookie = "rack.session=#{legacy_session}--#{legacy_digest}; path=/; HttpOnly"

    app = [incrementor, { secret: secret, legacy_hmac_secret: legacy_secret }]
    response = response_for(app: app, cookie: legacy_cookie)
    expect(response.body).to eq('{"counter"=>2}')
  end

  it 'ignores tampered with session cookies' do
    app = [incrementor, { secret: secret }]
    response = response_for(app: app)
    expect(response.body).to eq('{"counter"=>1}')

    response = response_for(app: app, cookie: response)
    expect(response.body).to eq('{"counter"=>2}')

    ctxt, iv, auth_tag = response['Set-Cookie'].split('--', 3)
    tampered_with_cookie = [ctxt, iv, auth_tag.reverse].join('--')

    response = response_for(app: app, cookie: tampered_with_cookie)
    expect(response.body).to eq('{"counter"=>1}')
  end

  it 'ignores tampered with legacy hmac cookie' do
    legacy_session = Rack::Protection::EncryptedCookie::Base64::Marshal.new.encode({ 'counter' => 1, 'session_id' => 'abcdef' })
    legacy_secret  = 'test legacy secret'
    legacy_digest  = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('SHA1'), legacy_secret, legacy_session).reverse

    legacy_cookie = "rack.session=#{legacy_session}--#{legacy_digest}; path=/; HttpOnly"

    app = [incrementor, { secret: secret, legacy_hmac_secret: legacy_secret }]
    response = response_for(app: app, cookie: legacy_cookie)
    expect(response.body).to eq('{"counter"=>1}')
  end

  it 'supports either of secret or old_secret' do
    app = [incrementor, { secret: secret }]
    response = response_for(app: app)
    expect(response.body).to eq('{"counter"=>1}')

    response = response_for(app: app, cookie: response)
    expect(response.body).to eq('{"counter"=>2}')

    app = [incrementor, { old_secret: secret }]
    response = response_for(app: app)
    expect(response.body).to eq('{"counter"=>1}')

    response = response_for(app: app, cookie: response)
    expect(response.body).to eq('{"counter"=>2}')
  end

  it 'supports custom digest class for legacy hmac cookie' do
    legacy_hmac    = OpenSSL::Digest::SHA256
    legacy_session = Rack::Protection::EncryptedCookie::Base64::Marshal.new.encode({ 'counter' => 1, 'session_id' => 'abcdef' })
    legacy_secret  = 'test legacy secret'
    legacy_digest  = OpenSSL::HMAC.hexdigest(legacy_hmac.new, legacy_secret, legacy_session)
    legacy_cookie = "rack.session=#{Rack::Utils.escape legacy_session}--#{legacy_digest}; path=/; HttpOnly"

    app = [incrementor, {
      secret: secret, legacy_hmac_secret: legacy_secret, legacy_hmac: legacy_hmac
    }]

    response = response_for(app: app, cookie: legacy_cookie)
    expect(response.body).to eq('{"counter"=>2}')

    response = response_for(app: app, cookie: response)
    expect(response.body).to eq('{"counter"=>3}')
  end

  it 'can handle Rack::Lint middleware' do
    response = response_for(app: incrementor)

    lint = Rack::Lint.new(session_id)
    response = response_for(app: lint, cookie: response)
    expect(response.body).to_not be_nil
  end

  it 'can handle middleware that inspects the env' do
    class TestEnvInspector
      def initialize(app)
        @app = app
      end

      def call(env)
        env.inspect
        @app.call(env)
      end
    end

    response = response_for(app: incrementor)

    inspector = TestEnvInspector.new(session_id)
    response = response_for(app: inspector, cookie: response)
    expect(response.body).to_not be_nil
  end

  it 'returns the session id in the session hash' do
    response = response_for(app: incrementor)
    expect(response.body).to eq('{"counter"=>1}')

    response = response_for(app: session_id, cookie: response)
    expect(response.body).to match(/"session_id"=>/)
    expect(response.body).to match(/"counter"=>1/)
  end

  it 'does not return a cookie if set to secure but not using ssl' do
    app = [incrementor, { secure: true }]

    response = response_for(app: app)
    expect(response['Set-Cookie']).to be_nil

    response = response_for(app: app, request: { 'HTTPS' => 'on' })
    expect(response['Set-Cookie']).to_not be_nil
    expect(response['Set-Cookie']).to match(/secure/)
  end

  it 'does not return a cookie if cookie was not read/written' do
    response = response_for(app: nothing)
    expect(response['Set-Cookie']).to be_nil
  end

  it 'does not return a cookie if cookie was not written (only read)' do
    response = response_for(app: session_id)
    expect(response['Set-Cookie']).to be_nil
  end

  it 'returns even if not read/written if :expire_after is set' do
    app = [nothing, { expire_after: 3600 }]
    request = { 'rack.session' => { 'not' => 'empty' } }
    response = response_for(app: app, request: request)
    expect(response['Set-Cookie']).to_not be_nil
  end

  it 'returns no cookie if no data was written and no session was created previously, even if :expire_after is set' do
    app = [nothing, { expire_after: 3600 }]
    response = response_for(app: app)
    expect(response['Set-Cookie']).to be_nil
  end

  it "exposes :secret in env['rack.session.option']" do
    response = response_for(app: [session_option[:secret], { secret: secret }])
    expect(response.body).to eq(secret.inspect)
  end

  it "exposes :coder in env['rack.session.option']" do
    response = response_for(app: session_option[:coder])
    expect(response.body).to match(/Base64::Marshal/)
  end

  it 'exposes correct :coder when a secret is used' do
    response = response_for(app: session_option[:coder], secret: secret)
    expect(response.body).to match(/Marshal/)
  end

  it 'allows passing in a hash with session data from middleware in front' do
    request = { 'rack.session' => { foo: 'bar' } }
    response = response_for(app: session_id, request: request)
    expect(response.body).to match(/foo/)
  end

  it 'allows modifying session data with session data from middleware in front' do
    request = { 'rack.session' => { foo: 'bar' } }
    response = response_for(app: incrementor, request: request)
    expect(response.body).to match(/counter/)
    expect(response.body).to match(/foo/)
  end

  it "allows more than one '--' in the cookie when calculating legacy digests" do
    @counter = 0
    app = lambda do |env|
      env['rack.session']['message'] ||= ''
      env['rack.session']['message'] << "#{@counter += 1}--"
      hash = env['rack.session'].dup
      hash.delete('session_id')
      Rack::Response.new(hash['message']).to_a
    end
    # another example of an unsafe coder is Base64.urlsafe_encode64
    unsafe_coder = Class.new do
      def encode(hash); hash.inspect end
      def decode(str); eval(str) if str; end
    end.new

    legacy_session = unsafe_coder.encode('message' => "#{@counter += 1}--#{@counter += 1}--", 'session_id' => 'abcdef')
    legacy_secret  = 'test legacy secret'
    legacy_digest  = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('SHA1'), legacy_secret, legacy_session)
    legacy_cookie = "rack.session=#{Rack::Utils.escape legacy_session}--#{legacy_digest}; path=/; HttpOnly"

    _app = [app, {
      secret: secret, legacy_hmac_secret: legacy_secret,
      legacy_hmac_coder: unsafe_coder
    }]

    response = response_for(app: _app, cookie: legacy_cookie)
    expect(response.body).to eq('1--2--3--')
  end

  it 'allows for non-strict encoded cookie' do
    long_session_app = lambda do |env|
      env['rack.session']['value'] = 'A' * 256
      env['rack.session']['counter'] = 1
      hash = env['rack.session'].dup
      hash.delete('session_id')
      Rack::Response.new(hash.inspect).to_a
    end

    non_strict_coder = Class.new do
      def encode(str)
        [Marshal.dump(str)].pack('m')
      end

      def decode(str)
        return unless str

        Marshal.load(str.unpack1('m'))
      end
    end.new

    non_strict_response = response_for(app: [
                                         long_session_app, { coder: non_strict_coder }
                                       ])

    response = response_for(app: [
                              incrementor
                            ], cookie: non_strict_response)

    expect(response.body).to match(%("value"=>"#{'A' * 256}"))
    expect(response.body).to match('"counter"=>2')
    expect(response.body).to match(/\A{[^}]+}\z/)
  end
end
