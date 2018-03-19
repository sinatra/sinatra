require 'sinatra/base'
require 'backports'

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
      env['async.close'].callback { stream.close } if env.key? 'async.close'
      stream
    end

    module Stream

      attr_accessor :app, :lineno, :pos, :transformer, :closed
      alias tell pos
      alias closed? closed

      def self.extended(obj)
        obj.closed, obj.lineno, obj.pos = false, 0, 0
        obj.callback { obj.closed = true }
        obj.errback  { obj.closed = true }
      end

      def <<(data)
        raise IOError, 'not opened for writing' if closed?

        @transformer ||= nil
        data = data.to_s
        data = @transformer[data] if @transformer
        @pos += data.bytesize
        super(data)
      end

      def each
        # that way body.each.map { ... } works
        return self unless block_given?
        super
      end

      def map(&block)
        # dup would not copy the mixin
        clone.map!(&block)
      end

      def map!(&block)
        @transformer ||= nil

        if @transformer
          inner, outer = @transformer, block
          block = proc { |value| outer[inner[value]] }
        end
        @transformer = block
        self
      end

      def write(data)
        self << data
        data.to_s.bytesize
      end

      alias syswrite      write
      alias write_nonblock write

      def print(*args)
        args.each { |arg| self << arg }
        nil
      end

      def printf(format, *args)
        print(format.to_s % args)
      end

      def putc(c)
        print c.chr
      end

      def puts(*args)
        args.each { |arg| self << "#{arg}\n" }
        nil
      end

      def close_read
        raise IOError, "closing non-duplex IO for reading"
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

      def closed?
        @closed
      end

      def settings
        app.settings
      end

      def rewind
        @pos = @lineno = 0
      end

      def not_open_for_reading(*)
        raise IOError, "not opened for reading"
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
    end
  end

  helpers Streaming
end
