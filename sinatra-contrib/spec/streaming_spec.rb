require 'backports'
require 'spec_helper'

describe Sinatra::Streaming do
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
      ran.should be true
    end

    it 'returns the stream object' do
      out = stream { }
      out.should be_a(Sinatra::Helpers::Stream)
    end

    it 'fires a request against that stream' do
      stream { |out| out << "Hello World!" }
      last_response.should be_ok
      body.should be == "Hello World!"
    end

    it 'passes the stream object to the block' do
      passed   = nil
      returned = stream { |out| passed = out }
      passed.should be == returned
    end
  end

  context Sinatra::Streaming::Stream do
    it 'should extend the stream object' do
      out = stream { }
      out.should be_a(Sinatra::Streaming::Stream)
    end

    it 'should not extend stream objects of other apps' do
      out = nil
      mock_app { get('/') { out = stream { }}}
      get('/')
      out.should be_a(Sinatra::Helpers::Stream)
      out.should_not be_a(Sinatra::Streaming::Stream)
    end
  end

  context 'app' do
    it 'is the app instance the stream was created from' do
      out = stream { }
      out.app.should be_a(Sinatra::Base)
    end
  end

  context 'lineno' do
    it 'defaults to 0' do
      stream { }.lineno.should be == 0
    end

    it 'does not increase on write' do
      stream do |out|
        out << "many\nlines\n"
        out.lineno.should be == 0
      end
    end

    it 'is writable' do
      out = stream { }
      out.lineno = 10
      out.lineno.should be == 10
    end
  end

  context 'pos' do
    it 'defaults to 0' do
      stream { }.pos.should be == 0
    end

    it 'increases when writing data' do
      stream do |out|
        out.pos.should be == 0
        out << 'hi'
        out.pos.should be == 2
      end
    end

    it 'is writable' do
      out = stream { }
      out.pos = 10
      out.pos.should be == 10
    end

    it 'aliased to #tell' do
      out = stream { }
      out.tell.should be == 0
      out.pos = 10
      out.tell.should be == 10
    end
  end

  context 'closed' do
    it 'returns false while streaming' do
      stream { |out| out.should_not be_closed }
    end

    it 'returns true after streaming' do
      stream {}.should be_closed
    end
  end

  context 'map!' do
    it 'applies transformations later' do
      stream do |out|
        out.map! { |s| s.upcase }
        out << 'ok'
      end
      body.should be == "OK"
    end

    it 'is chainable' do
      stream do |out|
        out.map! { |s| s.upcase }
        out.map! { |s| s.reverse }
        out << 'ok'
      end
      body.should be == "KO"
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
      body.should be == "OK"
    end

    it 'modifies each value separately' do
      stream do |out|
        out.map! { |s| s.reverse }
        out << "ab" << "cd"
      end
      body.should be == "badc"
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
      body.should be == "OK"
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
      body.should be == "KO"
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
      body.should be == "OK"
    end

    it 'does not modify the original body' do
      stream do |out|
        out.map { |s| s.reverse }
        out << 'ok'
      end
      body.should be == 'ok'
    end
  end

  context 'write' do
    it 'writes to the stream' do
      stream { |out| out.write 'hi' }
      body.should be == 'hi'
    end

    it 'returns the number of bytes' do
      stream do |out|
        out.write('hi').should be == 2
        out.write('hello').should be == 5
      end
    end

    it 'accepts non-string objects' do
      stream do |out|
        out.write(12).should be == 2
      end
    end

    it 'should be aliased to syswrite' do
      stream { |out| out.syswrite('hi').should be == 2 }
      body.should be == 'hi'
    end

    it 'should be aliased to write_nonblock' do
      stream { |out| out.write_nonblock('hi').should be == 2 }
      body.should be == 'hi'
    end
  end

  context 'print' do
    it 'writes to the stream' do
      stream { |out| out.print('hi') }
      body.should be == 'hi'
    end

    it 'accepts multiple arguments' do
      stream { |out| out.print(1, 2, 3, 4) }
      body.should be == '1234'
    end

    it 'returns nil' do
      stream { |out| out.print('hi').should be_nil }
    end
  end

  context 'printf' do
    it 'writes to the stream' do
      stream { |out| out.printf('hi') }
      body.should be == 'hi'
    end

    it 'interpolates the format string' do
      stream { |out| out.printf("%s: %d", "answer", 42) }
      body.should be == 'answer: 42'
    end

    it 'returns nil' do
      stream { |out| out.printf('hi').should be_nil }
    end
  end

  context 'putc' do
    it 'writes the first character of a string' do
      stream { |out| out.putc('hi') }
      body.should be == 'h'
    end

    it 'writes the character corresponding to an integer' do
      stream { |out| out.putc(42) }
      body.should be == '*'
    end

    it 'returns nil' do
      stream { |out| out.putc('hi').should be_nil }
    end
  end

  context 'puts' do
    it 'writes to the stream' do
      stream { |out| out.puts('hi') }
      body.should be == "hi\n"
    end

    it 'accepts multiple arguments' do
      stream { |out| out.puts(1, 2, 3, 4) }
      body.should be == "1\n2\n3\n4\n"
    end

    it 'returns nil' do
      stream { |out| out.puts('hi').should be_nil }
    end
  end

  context 'close' do
    it 'sets #closed? to true' do
      stream do |out|
        out.close
        out.should be_closed
      end
    end

    it 'sets #closed_write? to true' do
      stream do |out|
        out.should_not be_closed_write
        out.close
        out.should be_closed_write
      end
    end

    it 'fires callbacks' do
      stream do |out|
        fired = false
        out.callback { fired = true }
        out.close
        fired.should be true
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
    it('returns true') { stream { |out| out.should be_closed_read }}
  end

  context 'rewind' do
    it 'resets pos' do
      stream do |out|
        out << 'hi'
        out.rewind
        out.pos.should be == 0
      end
    end

    it 'resets lineno' do
      stream do |out|
        out.lineno = 10
        out.rewind
        out.lineno.should be == 0
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
        stream { |out| out.public_send(method).should be_a(Enumerator) }
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
        stream { |out| out.public_send(method).should be_nil }
      end
    end
  end
end
