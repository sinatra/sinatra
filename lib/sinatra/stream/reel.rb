class Rack::ChunkedResponse < Rack::Response
  extend Forwardable
  def_delegators :@io, :read, :write, :read_nonblock, :write_nonblock, :flush, 
		       :close, :close_read, :close_write, :closed?

  def schedule
    yield
  end 

  class Writer
    extend Forwardable
    def_delegators :@io, :read, :write, :read_nonblock, :write_nonblock, :flush, 
		         :close, :close_read, :close_write, :closed?

    def initialize(io, context)
      @io = io
      @context = context
    end

    def write(data)
      @context.schedule { @io.write(data) }
    end
    alias :<< :write

    def callback(&block)
      @callbacks << block
    end
    
    def close
      @io.close unless @io.closed?
      @callbacks.each do |c|
        @context.schedule { c.call }
      end
    end
    
    def closed? ; !@io or @io.closed? ; end

    alias :errback :callback
  end
end

 
class Rack::StreamingResponse < Rack::ChunkedResponse
  CRLF = "\r\n"

  STREAMINGHEADERS={
    "Content-Type"       => "text/event-stream",
    "Transfer-Encoding"  => "identity",
    "Cache-Control"      => "no-cache"
  }

  def hijack!(env)
    return if @io
    env['rack.hijack'].call
    @io = Writer.new(env['rack.hijack_io'], self)
    @io.write render_header
  end

  private

  def render_header
    response_header = "#{version} #{status}#{CRLF}"
    unless headers.empty?
      response_header << headers.merge(STREAMINGHEADERS).map do |header, value|
        "#{header}: #{value}"
      end.join(CRLF) << CRLF
    end
    response_header << CRLF
  end

  # TODO: should be supplied by or passed to the web server
  def version ; "HTTP/1.1" ; end
end
