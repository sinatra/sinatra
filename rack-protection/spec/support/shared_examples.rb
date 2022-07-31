# frozen_string_literal: true

RSpec.shared_examples_for 'any rack application' do
  it 'should not interfere with normal get requests' do
    expect(get('/')).to be_ok
    expect(body).to eq('ok')
  end

  it 'should not interfere with normal head requests' do
    expect(head('/')).to be_ok
  end

  it 'should not leak changes to env' do
    klass    = described_class
    detector = Struct.new(:app) do
      def call(env)
        was = env.dup
        res = app.call(env)
        was.each do |k, v|
          next if env[k] == v

          raise "env[#{k.inspect}] changed from #{v.inspect} to #{env[k].inspect}"
        end
        res
      end
    end

    mock_app do
      use Rack::Head
      use(Rack::Config) { |e| e['rack.session'] ||= {} }
      use detector
      use klass
      run DummyApp
    end

    expect(get('/..', foo: '<bar>')).to be_ok
  end

  it 'allows passing on values in env' do
    klass    = described_class
    changer  = Struct.new(:app) do
      def call(env)
        env['foo.bar'] = 42
        app.call(env)
      end
    end
    detector = Struct.new(:app) do
      def call(env)
        app.call(env)
      end
    end

    expect_any_instance_of(detector).to receive(:call).with(
      hash_including('foo.bar' => 42)
    ).and_call_original

    mock_app do
      use Rack::Head
      use(Rack::Config) { |e| e['rack.session'] ||= {} }
      use changer
      use klass
      use detector
      run DummyApp
    end

    expect(get('/')).to be_ok
  end
end
