require 'spec_helper'

RSpec.describe Sinatra::Streaming do
  def stream(&block)
    rack_middleware = @use
    out = nil
    mock_app do
      rack_middleware.each { |args| use(*args) }
      helpers Sinatra::Streaming
      get('/') { out = stream(&block) }
    end
    get('/')
    out
  end

  def use(*args)
    @use << args
  end

  before do
    @use = []
  end

  context 'stream test helper' do
    it 'runs the given block' do
      ran = false
      stream { ran = true }
      expect(ran).to be true
    end

    it 'returns the stream object' do
      out = stream { }
      expect(out).to be_a(Sinatra::Helpers::Stream)
    end

    it 'fires a request against that stream' do
      stream { |out| out << "Hello World!" }
      expect(last_response).to be_ok
      expect(body).to eq("Hello World!")
    end

    it 'passes the stream object to the block' do
      passed   = nil
      returned = stream { |out| passed = out }
      expect(passed).to eq(returned)
    end
  end

  context Sinatra::Streaming::Stream do
    it 'should extend the stream object' do
      out = stream { }
      expect(out).to be_a(Sinatra::Streaming::Stream)
    end

    it 'should not extend stream objects of other apps' do
      out = nil
      mock_app { get('/') { out = stream { }}}
      get('/')
      expect(out).to be_a(Sinatra::Helpers::Stream)
      expect(out).not_to be_a(Sinatra::Streaming::Stream)
    end
  end

  context 'app' do
    it 'is the app instance the stream was created from' do
      out = stream { }
      expect(out.app).to be_a(Sinatra::Base)
    end
  end

  context 'lineno' do
    it 'defaults to 0' do
      expect(stream { }.lineno).to eq(0)
    end

    it 'does not increase on write' do
      stream do |out|
        out << "many\nlines\n"
        expect(out.lineno).to eq(0)
      end
    end

    it 'is writable' do
      out = stream { }
      out.lineno = 10
      expect(out.lineno).to eq(10)
    end
  end

  context 'pos' do
    it 'defaults to 0' do
      expect(stream { }.pos).to eq(0)
    end

    it 'increases when writing data' do
      stream do |out|
        expect(out.pos).to eq(0)
        out << 'hi'
        expect(out.pos).to eq(2)
      end
    end

    it 'is writable' do
      out = stream { }
      out.pos = 10
      expect(out.pos).to eq(10)
    end

    it 'aliased to #tell' do
      out = stream { }
      expect(out.tell).to eq(0)
      out.pos = 10
      expect(out.tell).to eq(10)
    end
  end

  context 'closed' do
    it 'returns false while streaming' do
      stream { |out| expect(out).not_to be_closed }
    end

    it 'returns true after streaming' do
      expect(stream {}).to be_closed
    end
  end

  context 'map!' do
    it 'applies transformations later' do
      stream do |out|
        out.map! { |s| s.upcase }
        out << 'ok'
      end
      expect(body).to eq("OK")
    end

    it 'is chainable' do
      stream do |out|
        out.map! { |s| s.upcase }
        out.map! { |s| s.reverse }
        out << 'ok'
      end
      expect(body).to eq("KO")
    end

    it 'works with middleware' do
      middleware = Class.new do
        def initialize(app) @app = app end
        def call(env)
          status, headers, body = @app.call(env)
          body.map! { |s| s.upcase }
          [status, headers, body]
        end
      end

      use middleware
      stream { |out| out << "ok" }
      expect(body).to eq("OK")
    end

    it 'modifies each value separately' do
      stream do |out|
        out.map! { |s| s.reverse }
        out << "ab" << "cd"
      end
      expect(body).to eq("badc")
    end
  end

  context 'map' do
    it 'works with middleware' do
      middleware = Class.new do
        def initialize(app) @app = app end
        def call(env)
          status, headers, body = @app.call(env)
          [status, headers, body.map(&:upcase)]
        end
      end

      use middleware
      stream { |out| out << "ok" }
      expect(body).to eq("OK")
    end

    it 'is chainable' do
      middleware = Class.new do
        def initialize(app) @app = app end
        def call(env)
          status, headers, body = @app.call(env)
          [status, headers, body.map(&:upcase).map(&:reverse)]
        end
      end

      use middleware
      stream { |out| out << "ok" }
      expect(body).to eq("KO")
    end

    it 'can be written as each.map' do
      middleware = Class.new do
        def initialize(app) @app = app end
        def call(env)
          status, headers, body = @app.call(env)
          [status, headers, body.each.map(&:upcase)]
        end
      end

      use middleware
      stream { |out| out << "ok" }
      expect(body).to eq("OK")
    end

    it 'does not modify the original body' do
      stream do |out|
        out.map { |s| s.reverse }
        out << 'ok'
      end
      expect(body).to eq('ok')
    end
  end

  context 'write' do
    it 'writes to the stream' do
      stream { |out| out.write 'hi' }
      expect(body).to eq('hi')
    end

    it 'returns the number of bytes' do
      stream do |out|
        expect(out.write('hi')).to eq(2)
        expect(out.write('hello')).to eq(5)
      end
    end

    it 'accepts non-string objects' do
      stream do |out|
        expect(out.write(12)).to eq(2)
      end
    end

    it 'should be aliased to syswrite' do
      stream { |out| expect(out.syswrite('hi')).to eq(2) }
      expect(body).to eq('hi')
    end

    it 'should be aliased to write_nonblock' do
      stream { |out| expect(out.write_nonblock('hi')).to eq(2) }
      expect(body).to eq('hi')
    end
  end

  context 'print' do
    it 'writes to the stream' do
      stream { |out| out.print('hi') }
      expect(body).to eq('hi')
    end

    it 'accepts multiple arguments' do
      stream { |out| out.print(1, 2, 3, 4) }
      expect(body).to eq('1234')
    end

    it 'returns nil' do
      stream { |out| expect(out.print('hi')).to be_nil }
    end
  end

  context 'printf' do
    it 'writes to the stream' do
      stream { |out| out.printf('hi') }
      expect(body).to eq('hi')
    end

    it 'interpolates the format string' do
      stream { |out| out.printf("%s: %d", "answer", 42) }
      expect(body).to eq('answer: 42')
    end

    it 'returns nil' do
      stream { |out| expect(out.printf('hi')).to be_nil }
    end
  end

  context 'putc' do
    it 'writes the first character of a string' do
      stream { |out| out.putc('hi') }
      expect(body).to eq('h')
    end

    it 'writes the character corresponding to an integer' do
      stream { |out| out.putc(42) }
      expect(body).to eq('*')
    end

    it 'returns nil' do
      stream { |out| expect(out.putc('hi')).to be_nil }
    end
  end

  context 'puts' do
    it 'writes to the stream' do
      stream { |out| out.puts('hi') }
      expect(body).to eq("hi\n")
    end

    it 'accepts multiple arguments' do
      stream { |out| out.puts(1, 2, 3, 4) }
      expect(body).to eq("1\n2\n3\n4\n")
    end

    it 'returns nil' do
      stream { |out| expect(out.puts('hi')).to be_nil }
    end
  end

  context 'close' do
    it 'sets #closed? to true' do
      stream do |out|
        out.close
        expect(out).to be_closed
      end
    end

    it 'sets #closed_write? to true' do
      stream do |out|
        expect(out).not_to be_closed_write
        out.close
        expect(out).to be_closed_write
      end
    end

    it 'fires callbacks' do
      stream do |out|
        fired = false
        out.callback { fired = true }
        out.close
        expect(fired).to be true
      end
    end

    it 'prevents from further writing' do
      stream do |out|
        out.close
        expect { out << 'hi' }.to raise_error(IOError, 'not opened for writing')
      end
    end
  end

  context 'close_read' do
    it 'raises the appropriate exception' do
      expect { stream { |out| out.close_read }}.
        to raise_error(IOError, "closing non-duplex IO for reading")
    end
  end

  context 'closed_read?' do
    it('returns true') { stream { |out| expect(out).to be_closed_read }}
  end

  context 'rewind' do
    it 'resets pos' do
      stream do |out|
        out << 'hi'
        out.rewind
        expect(out.pos).to eq(0)
      end
    end

    it 'resets lineno' do
      stream do |out|
        out.lineno = 10
        out.rewind
        expect(out.lineno).to eq(0)
      end
    end
  end

  raises = %w[
    bytes eof? eof getbyte getc gets read read_nonblock readbyte readchar
    readline readlines readpartial sysread ungetbyte ungetc
  ]

  enum    = %w[chars each_line each_byte each_char lines]
  dummies = %w[flush fsync internal_encoding pid]

  raises.each do |method|
    context method do
      it 'raises the appropriate exception' do
        expect { stream { |out| out.public_send(method) }}.
          to raise_error(IOError, "not opened for reading")
      end
    end
  end

  enum.each do |method|
    context method do
      it 'creates an Enumerator' do
        stream { |out| expect(out.public_send(method)).to be_a(Enumerator) }
      end

      it 'calling each raises the appropriate exception' do
        expect { stream { |out| out.public_send(method).each { }}}.
          to raise_error(IOError, "not opened for reading")
      end
    end
  end

  dummies.each do |method|
    context method do
      it 'returns nil' do
        stream { |out| expect(out.public_send(method)).to be_nil }
      end
    end
  end
end
