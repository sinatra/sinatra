# frozen_string_literal: true

require 'sinatra/base'

module Sinatra
  # = Sinatra::Streaming
  #
  # Sinatra 1.3 introduced the +stream+ helper. This addon improves the
  # streaming API by making the stream object imitate an IO object, turning
  # it into a real Deferrable and making the body play nicer with middleware
  # unaware of streaming.
  #
  # == IO-like behavior
  #
  # This is useful when passing the stream object to a library expecting an
  # IO or StringIO object.
  #
  #   get '/' do
  #     stream do |out|
  #       out.puts "Hello World!", "How are you?"
  #       out.write "Written #{out.pos} bytes so far!\n"
  #       out.putc(65) unless out.closed?
  #       out.flush
  #     end
  #   end
  #
  # == Better Middleware Handling
  #
  # Blocks passed to #map! or #map will actually be applied when streaming
  # takes place (as you might have suspected, #map! applies modifications
  # to the current body, while #map creates a new one):
  #
  #   class StupidMiddleware
  #     def initialize(app) @app = app end
  #
  #     def call(env)
  #       status, headers, body = @app.call(env)
  #       body.map! { |e| e.upcase }
  #       [status, headers, body]
  #     end
  #   end
  #
  #   use StupidMiddleware
  #
  #   get '/' do
  #     stream do |out|
  #       out.puts "still"
  #       sleep 1
  #       out.puts "streaming"
  #     end
  #   end
  #
  # Even works if #each is used to generate an Enumerator:
  #
  #   def call(env)
  #     status, headers, body = @app.call(env)
  #     body = body.each.map { |s| s.upcase }
  #     [status, headers, body]
  #   end
  #
  # Note that both examples violate the Rack specification.
  #
  # == Rack 3 callable body
  #
  # Sinatra core's +Sinatra::Helpers::Stream+ is a Rack 3 *callable* streaming
  # body (it responds to #call, not #each), so a Rack 3 server drives it in push
  # mode. This addon re-adds the IO emulation and the #each/#map/#map! middleware
  # tricks on top of that callable body: a stream extended with
  # Sinatra::Streaming::Stream becomes #each-able again (it drives the producer
  # block and buffers the writes), which is what makes #map/#map! and
  # middleware-unaware buffering work. As before, this trades Rack 3 push-mode
  # for enumerable compatibility, which technically violates the Rack streaming
  # contract; use the native +stream+ helper if you need true push streaming.
  #
  # == Setup
  #
  # In a classic application:
  #
  #   require "sinatra"
  #   require "sinatra/streaming"
  #
  # In a modular application:
  #
  #   require "sinatra/base"
  #   require "sinatra/streaming"
  #
  #   class MyApp < Sinatra::Base
  #     helpers Sinatra::Streaming
  #   end
  module Streaming
    def stream(*)
      stream = super
      stream.extend Stream
      stream.app = self
      stream
    end

    module Stream
      attr_accessor :app, :lineno, :pos, :transformer, :closed
      alias tell pos
      alias closed? closed

      # Initialize the IO-emulation ivars exactly once, at extend time, so the
      # object shape stays stable (no lazily-assigned ivars on the hot path).
      def self.extended(obj)
        obj.closed      = false
        obj.lineno      = 0
        obj.pos         = 0
        obj.transformer = nil
        obj.callback { obj.closed = true }
        obj.errback  { obj.closed = true }
      end

      # Drive the underlying callable body, buffering each write so the body is
      # consumable as an Enumerable (this is what re-enables #map/#map! and the
      # middleware tricks on top of the Rack 3 callable body). With no block,
      # returns self so `body.each.map { ... }` works.
      def each(&block)
        return self unless block_given?

        call(Collector.new(block))
        self
      end

      def map(&block)
        # dup would not copy the mixin
        clone.map!(&block)
      end

      def map!(&block)
        if transformer
          inner = transformer
          outer = block
          block = proc { |value| outer[inner[value]] }
        end
        self.transformer = block
        self
      end

      def <<(data)
        raise IOError, 'not opened for writing' if closed?

        data = data.to_s
        data = transformer[data] if transformer
        self.pos += data.bytesize
        super(data)
      end

      def write(data)
        self << data
        data.to_s.bytesize
      end

      alias syswrite write
      alias write_nonblock write

      def print(*args)
        args.each { |arg| self << arg }
        nil
      end

      def printf(format, *args)
        print(format.to_s % args)
      end

      def putc(c)
        print c.is_a?(Numeric) ? c.chr : c.to_s[0, 1]
      end

      def puts(*args)
        args.each { |arg| self << "#{arg}\n" }
        nil
      end

      def close_read
        raise IOError, 'closing non-duplex IO for reading'
      end

      def closed_read?
        true
      end

      def closed_write?
        closed?
      end

      def external_encoding
        Encoding.find settings.default_encoding
      rescue NameError
        settings.default_encoding
      end

      def settings
        app.settings
      end

      def rewind
        self.pos = self.lineno = 0
      end

      def not_open_for_reading(*)
        raise IOError, 'not opened for reading'
      end

      alias bytes         not_open_for_reading
      alias eof?          not_open_for_reading
      alias eof           not_open_for_reading
      alias getbyte       not_open_for_reading
      alias getc          not_open_for_reading
      alias gets          not_open_for_reading
      alias read          not_open_for_reading
      alias read_nonblock not_open_for_reading
      alias readbyte      not_open_for_reading
      alias readchar      not_open_for_reading
      alias readline      not_open_for_reading
      alias readlines     not_open_for_reading
      alias readpartial   not_open_for_reading
      alias sysread       not_open_for_reading
      alias ungetbyte     not_open_for_reading
      alias ungetc        not_open_for_reading
      private :not_open_for_reading

      def enum_not_open_for_reading(*)
        not_open_for_reading if block_given?
        enum_for(:not_open_for_reading)
      end

      alias chars     enum_not_open_for_reading
      alias each_line enum_not_open_for_reading
      alias each_byte enum_not_open_for_reading
      alias each_char enum_not_open_for_reading
      alias lines     enum_not_open_for_reading
      undef enum_not_open_for_reading

      def dummy(*) end
      alias flush             dummy
      alias fsync             dummy
      alias internal_encoding dummy
      alias pid               dummy
      undef dummy

      def seek(*)
        0
      end

      alias sysseek seek

      def sync
        true
      end

      def tty?
        false
      end

      alias isatty tty?

      # Stands in for the Rack 3 server stream while #each buffers a callable
      # body: every write the producer block performs is forwarded to the #each
      # block instead of going to a socket. Implements just enough of the server
      # stream interface (#write, #flush, #close, #closed?) for the body to run.
      class Collector
        def initialize(sink)
          @sink   = sink
          @closed = false
        end

        def write(data)
          @sink.call(data)
          data.bytesize
        end

        def <<(data)
          write(data)
          self
        end

        def flush;   self end
        def read(*)  nil  end

        def close
          @closed = true
        end

        def closed?
          @closed
        end
      end
    end
  end

  helpers Streaming
end
