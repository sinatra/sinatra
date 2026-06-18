# frozen_string_literal: true

# external dependencies
require 'rack'
begin
  require 'rackup'
rescue LoadError
end
require 'tilt'
require 'rack/protection'
require 'rack/session'
require 'mustermann'
require 'mustermann/sinatra'
require 'mustermann/regular'

# stdlib dependencies
require 'ipaddr'
require 'socket' # BasicSocket / Socket::MSG_PEEK for streaming disconnect probe
require 'time'
require 'uri'

# other files we need
require 'sinatra/indifferent_hash'
require 'sinatra/show_exceptions'
require 'sinatra/version'

require_relative 'middleware/logger'

module Sinatra
  # The request object. See Rack::Request for more info:
  # https://rubydoc.info/github/rack/rack/main/Rack/Request
  class Request < Rack::Request
    HEADER_PARAM = /\s*[\w.]+=(?:[\w.]+|"(?:[^"\\]|\\.)*")?\s*/.freeze
    HEADER_VALUE_WITH_PARAMS = %r{(?:(?:\w+|\*)/(?:\w+(?:\.|-|\+)?|\*)*)\s*(?:;#{HEADER_PARAM})*}.freeze

    # Returns an array of acceptable media types for the response
    def accept
      @env['sinatra.accept'] ||= if @env.include?('HTTP_ACCEPT') && (@env['HTTP_ACCEPT'].to_s != '')
                                   @env['HTTP_ACCEPT']
                                     .to_s
                                     .scan(HEADER_VALUE_WITH_PARAMS)
                                     .map! { |e| AcceptEntry.new(e) }
                                     .sort
                                 else
                                   [AcceptEntry.new('*/*')]
                                 end
    end

    def accept?(type)
      preferred_type(type).to_s.include?(type)
    end

    def preferred_type(*types)
      return accept.first if types.empty?

      types.flatten!
      return types.first if accept.empty?

      accept.detect do |accept_header|
        type = types.detect { |t| MimeTypeEntry.new(t).accepts?(accept_header) }
        return type if type
      end
    end

    alias secure? ssl?

    def forwarded?
      !forwarded_authority.nil?
    end

    def safe?
      get? || head? || options? || trace?
    end

    def idempotent?
      safe? || put? || delete? || link? || unlink?
    end

    def link?
      request_method == 'LINK'
    end

    def unlink?
      request_method == 'UNLINK'
    end

    def params
      super
    rescue Rack::Utils::ParameterTypeError, Rack::Utils::InvalidParameterError => e
      raise BadRequest, "Invalid query parameters: #{Rack::Utils.escape_html(e.message)}"
    rescue EOFError => e
      raise BadRequest, "Invalid multipart/form-data: #{Rack::Utils.escape_html(e.message)}"
    end

    class AcceptEntry
      attr_accessor :params
      attr_reader :entry

      def initialize(entry)
        params = entry.scan(HEADER_PARAM).map! do |s|
          key, value = s.strip.split('=', 2)
          value = value[1..-2].gsub(/\\(.)/, '\1') if value.start_with?('"')
          [key, value]
        end

        @entry  = entry
        @type   = entry[/[^;]+/].delete(' ')
        @params = params.to_h
        @q      = @params.delete('q') { 1.0 }.to_f
      end

      def <=>(other)
        other.priority <=> priority
      end

      def priority
        # We sort in descending order; better matches should be higher.
        [@q, -@type.count('*'), @params.size]
      end

      def to_str
        @type
      end

      def to_s(full = false)
        full ? entry : to_str
      end

      def respond_to?(*args)
        super || to_str.respond_to?(*args)
      end

      def method_missing(*args, &block)
        to_str.send(*args, &block)
      end
    end

    class MimeTypeEntry
      attr_reader :params

      def initialize(entry)
        params = entry.scan(HEADER_PARAM).map! do |s|
          key, value = s.strip.split('=', 2)
          value = value[1..-2].gsub(/\\(.)/, '\1') if value.start_with?('"')
          [key, value]
        end

        @type   = entry[/[^;]+/].delete(' ')
        @params = params.to_h
      end

      def accepts?(entry)
        File.fnmatch(entry, self) && matches_params?(entry.params)
      end

      def to_str
        @type
      end

      def matches_params?(params)
        return true if @params.empty?

        params.all? { |k, v| !@params.key?(k) || @params[k] == v }
      end
    end
  end

  # The response object. See Rack::Response and Rack::Response::Helpers for
  # more info:
  # https://rubydoc.info/github/rack/rack/main/Rack/Response
  # https://rubydoc.info/github/rack/rack/main/Rack/Response/Helpers
  class Response < Rack::Response
    DROP_BODY_RESPONSES = [204, 304].freeze

    def body=(value)
      value = value.body while Rack::Response === value
      @body = String === value ? [value.to_str] : value
    end

    def each
      block_given? ? super : enum_for(:each)
    end

    def finish
      result = body

      if drop_content_info?
        headers.delete 'content-length'
        headers.delete 'content-type'
      end

      # U3: a streaming/callable body has no knowable length and is framed by
      # the server (chunked or close-delimited). Strip any Content-Length the
      # app hand-set, including one set AFTER the stream call (a route tail or
      # an after filter), which Helpers#body's strip cannot see. Done here at
      # the single finalization point, mirroring the lowercase 'content-length'
      # the Array === body fast-path above uses.
      headers.delete 'content-length' if streaming_body?

      if drop_body?
        close
        result = []
      end

      if calculate_content_length?
        # if some other code has already set content-length, don't muck with it
        # currently, this would be the static file-handler
        headers['content-length'] = body.map(&:bytesize).reduce(0, :+).to_s
      end

      [status, headers, result]
    end

    private

    def calculate_content_length?
      headers['content-type'] && !headers['content-length'] && (Array === body)
    end

    # A Rack 3 streaming body: a bare arity-1 callable (responds to #call, not
    # #each). Matches Helpers#body's streaming detection.
    def streaming_body?
      body.respond_to?(:call) && !body.respond_to?(:each)
    end

    def drop_content_info?
      informational? || drop_body?
    end

    def drop_body?
      DROP_BODY_RESPONSES.include?(status)
    end
  end

  # Deprecated, inert pass-through middleware. It once detected the extended
  # EventMachine/Thin async body protocol (async.callback / async.close /
  # throw :async) and routed it straight to the handler. That whole async path
  # was removed in Sinatra 5.0 in favour of the Rack 3 callable streaming body
  # (Sinatra::Helpers::Stream), so this class now does nothing but forward the
  # request. Sinatra no longer installs it by default; it survives only so that
  # an app which still `use Sinatra::ExtendedRack` keeps working (with a
  # deprecation warning) instead of raising NameError. It will be removed in
  # Sinatra 6.0.
  class ExtendedRack < Struct.new(:app)
    def initialize(app)
      super
      Sinatra::Base.send(
        :warn_for_deprecation,
        'Sinatra::ExtendedRack is deprecated and does nothing; the async ' \
        'streaming path it supported was removed in Sinatra 5.0. Remove ' \
        '`use Sinatra::ExtendedRack` from your middleware stack. It will be ' \
        'removed in Sinatra 6.0.'
      )
    end

    def call(env)
      app.call(env)
    end
  end

  # Behaves exactly like Rack::CommonLogger with the notable exception that it does nothing,
  # if another CommonLogger is already in the middleware chain.
  class CommonLogger < Rack::CommonLogger
    def call(env)
      env['sinatra.commonlogger'] ? @app.call(env) : super
    end

    superclass.class_eval do
      alias_method :call_without_check, :call unless method_defined? :call_without_check
      def call(env)
        env['sinatra.commonlogger'] = true
        call_without_check(env)
      end
    end
  end

  class Error < StandardError # :nodoc:
  end

  class BadRequest < Error # :nodoc:
    def http_status; 400 end
  end

  class NotFound < Error # :nodoc:
    def http_status; 404 end
  end

  # Methods available to routes, before/after filters, and views.
  module Helpers
    # Set or retrieve the response status code.
    def status(value = nil)
      response.status = Rack::Utils.status_code(value) if value
      response.status
    end

    # Set or retrieve the response body. When a block is given,
    # evaluation is deferred until the body is read with #each.
    def body(value = nil, &block)
      if block_given?
        def block.each; yield(call) end
        response.body = block
      elsif value
        # A raw Rack 3 streaming body is a callable that takes the server stream
        # (arity != 0) and is NOT an Enumerable body (does not respond to
        # #each). respond_to?(:arity) guards non-Proc #call objects, which raise
        # NoMethodError on #arity. Sinatra::Helpers::Stream flows through here
        # too (arity 1, no #each). For a streaming body the SERVER owns framing
        # (Rack 3 removed Rack::Chunked), so we must NOT carry a hand-set
        # Content-Length: see #strip_streaming_content_length! for the
        # response-splitting rationale.
        streaming = value.respond_to?(:call) && !value.respond_to?(:each) &&
                    (!value.respond_to?(:arity) || value.arity != 0)
        if streaming
          strip_streaming_content_length!
        elsif !(request.head? || value.is_a?(Rack::Files::BaseIterator))
          headers.delete 'content-length'
        end
        response.body = value
      else
        response.body
      end
    end

    # Halt processing and redirect to the URI provided.
    def redirect(uri, *args)
      http_version = env['SERVER_PROTOCOL']
      if (http_version == 'HTTP/1.1') && (env['REQUEST_METHOD'] != 'GET')
        status 303
      else
        status 302
      end

      # According to RFC 2616 section 14.30, "the field value consists of a
      # single absolute URI"
      response['Location'] = uri(uri.to_s, settings.absolute_redirects?, settings.prefixed_redirects?)
      halt(*args)
    end

    # Generates the absolute URI for a given path in the app.
    # Takes Rack routers and reverse proxies into account.
    def uri(addr = nil, absolute = true, add_script_name = true)
      return addr if addr.to_s =~ /\A[a-z][a-z0-9+.\-]*:/i

      uri = [host = String.new]
      if absolute
        host << "http#{'s' if request.secure?}://"
        host << if request.forwarded? || (request.port != (request.secure? ? 443 : 80))
                  request.host_with_port
                else
                  request.host
                end
      end
      uri << request.script_name.to_s if add_script_name
      uri << (addr || request.path_info).to_s
      File.join uri
    end

    alias url uri
    alias to uri

    # Halt processing and return the error status provided.
    def error(code, body = nil)
      if code.respond_to? :to_str
        body = code.to_str
        code = 500
      end
      response.body = body unless body.nil?
      halt code
    end

    # Halt processing and return a 404 Not Found.
    def not_found(body = nil)
      error 404, body
    end

    # Set multiple response headers with Hash.
    def headers(hash = nil)
      response.headers.merge! hash if hash
      response.headers
    end

    # Access the underlying Rack session.
    def session
      request.session
    end

    # Access shared logger object.
    def logger
      request.logger
    end

    # Look up a media type by file extension in Rack's mime registry.
    def mime_type(type)
      Base.mime_type(type)
    end

    # Set the content-type of the response body given a media type or file
    # extension.
    def content_type(type = nil, params = {})
      return response['content-type'] unless type

      default = params.delete :default
      mime_type = mime_type(type) || default
      raise format('Unknown media type: %p', type) if mime_type.nil?

      mime_type = mime_type.dup
      unless params.include?(:charset) || settings.add_charset.all? { |p| !(p === mime_type) }
        params[:charset] = params.delete('charset') || settings.default_encoding
      end
      params.delete :charset if mime_type.include? 'charset'
      unless params.empty?
        mime_type << ';'
        mime_type << params.map do |key, val|
          val = val.inspect if val.to_s =~ /[";,]/
          "#{key}=#{val}"
        end.join(';')
      end
      response['content-type'] = mime_type
    end

    # https://html.spec.whatwg.org/#multipart-form-data
    MULTIPART_FORM_DATA_REPLACEMENT_TABLE = {
      '"'  => '%22',
      "\r" => '%0D',
      "\n" => '%0A'
    }.freeze

    # Set the Content-Disposition to "attachment" with the specified filename,
    # instructing the user agents to prompt to save.
    def attachment(filename = nil, disposition = :attachment)
      response['Content-Disposition'] = disposition.to_s.dup
      return unless filename

      params = format('; filename="%s"', File.basename(filename).gsub(/["\r\n]/, MULTIPART_FORM_DATA_REPLACEMENT_TABLE))
      response['Content-Disposition'] << params
      ext = File.extname(filename)
      content_type(ext) unless response['content-type'] || ext.empty?
    end

    # Use the contents of the file at +path+ as the response body.
    def send_file(path, opts = {})
      if opts[:type] || !response['content-type']
        content_type opts[:type] || File.extname(path), default: 'application/octet-stream'
      end

      disposition = opts[:disposition]
      filename    = opts[:filename]
      disposition = :attachment if disposition.nil? && filename
      filename    = path        if filename.nil?
      attachment(filename, disposition) if disposition

      last_modified opts[:last_modified] if opts[:last_modified]

      file   = Rack::Files.new(File.dirname(settings.app_file))
      result = file.serving(request, path)

      result[1].each { |k, v| headers[k] ||= v }
      headers['content-length'] = result[1]['content-length']
      opts[:status] &&= Integer(opts[:status])
      halt (opts[:status] || result[0]), result[2]
    rescue Errno::ENOENT
      not_found
    end

    # The response body used by #stream. It is a Rack 3 *callable body*: it
    # responds to #call(stream) and deliberately NOT to #each, so Rack 3
    # servers (Puma 6+, Falcon, ...) treat it as a streaming body and drive it
    # in push mode. The same object is the +out+ handle the user writes to.
    #
    # The server hands #call a Rack stream (an IO-like object responding to
    # +write+/+<<+/+close+/+closed?+/...). The block supplied to #stream runs
    # once against this Stream; +out << data+ writes straight through to the
    # server stream (no internal buffer, the socket is the backpressure).
    class Stream
      # The socket errnos that mean "the peer is gone": a clean teardown, NOT
      # an application bug. Deliberately narrow: only these. We do NOT rescue
      # the whole SystemCallError tree, so a genuine app Errno::ENOENT (missing
      # file) / Errno::EACCES (permissions) raised inside the producer block
      # still propagates loudly instead of becoming a silent, truncated 200.
      DISCONNECT_ERRORS = [
        Errno::EPIPE, Errno::ECONNRESET, Errno::ECONNABORTED,
        Errno::ESHUTDOWN, Errno::ENOTCONN
      ].freeze

      # Raised ONLY by our own disconnect probe (peek/heartbeat). Modelled on
      # Rails' ActionController::Live::ClientDisconnected: a sentinel we control,
      # never confused with an app exception. Caught alongside DISCONNECT_ERRORS
      # and turned into a clean #close.
      class ClientDisconnected < RuntimeError; end

      # How often a parked keep_open #call re-probes for a vanished peer. Also
      # the upper bound on detection latency when no broadcast wakes us first
      # (server close, cross-request #close, reaper EOF, Falcon h2 RST_STREAM
      # all broadcast and wake us in ~1ms; this poll is the backstop).
      POLL = 15

      # Hard ceiling (seconds) on how long a single keep_open #call may park. If
      # every probe somehow misses a dead peer, this bounds the leak to one TTL
      # instead of forever, makes a saturated Puma pool self-recover, and gives
      # autoscalers a drain/rebalance point (a pinned long connection eventually
      # closes and the client reconnects, possibly to a fresher pod). Generous
      # by design so it does not interfere with normal long-lived SSE; pass
      # ttl: nil to opt out entirely, or ttl: N to tune. Jittered per-stream at
      # park time so TTLs do not all expire together into a reconnect storm.
      KEEP_OPEN_TTL = 300

      # Default write-probe byte string for a keep_open stream constructed
      # directly via Stream.new. It is the invisible SSE comment (a line
      # beginning with ':' is ignored by EventSource clients) so the low-level
      # API still reaps an idle Falcon-shape disconnect out of the box. The
      # public #stream helper overrides this: it passes the SSE comment only for
      # text/event-stream responses and nil otherwise, so an arbitrary
      # binary/long-poll body is never injected with bytes.
      DEFAULT_HEARTBEAT = ": \n"

      # Process-wide gauge of currently-parked keep_open streams. Used by the
      # public #stream helper to shed past settings.stream_max_concurrent. It is
      # per-process (per Puma worker / Falcon process); a clustered metric must
      # sum this across workers. Guarded by its own mutex so increment/decrement
      # is atomic under threads.
      @active       = 0
      @active_mutex = Mutex.new

      class << self
        # Current number of parked keep_open streams in this process.
        def active_count
          @active_mutex.synchronize { @active }
        end

        # Atomically claim a slot if we are below the cap. Returns true on
        # success, false if the cap is already reached (caller then sheds 503).
        # A nil cap means unlimited.
        def claim_slot(cap)
          @active_mutex.synchronize do
            return false if cap && @active >= cap

            @active += 1
            true
          end
        end

        def release_slot
          @active_mutex.synchronize { @active -= 1 if @active.positive? }
        end

        # Test seam: reset the gauge between examples.
        attr_writer :active
      end

      # Each keyword maps to a distinct, documented streaming concern (idle
      # heartbeat, parking ceiling, re-probe interval, wire protocol, error
      # reporting), so the list is intentionally wide rather than bundled into an
      # opaque options hash.
      # rubocop:disable Metrics/ParameterLists
      def initialize(keep_open = false, heartbeat: DEFAULT_HEARTBEAT,
                     ttl: KEEP_OPEN_TTL, poll: POLL, protocol: nil,
                     error_handlers: nil, &back)
        # rubocop:enable Metrics/ParameterLists
        @back           = back ? back.to_proc : proc {}
        @keep_open      = keep_open
        @heartbeat      = heartbeat
        @ttl            = ttl
        @poll           = poll
        @protocol       = protocol
        @error_handlers = error_handlers || []
        @callbacks      = []
        @closed         = false
        @stream         = nil
        @reason         = nil
        @slot_held      = false
        # Monotonic timestamp of the last successful application write. The
        # write-probe heartbeat only fires once a stream has been write-idle for
        # a full poll, so an actively-writing stream is never given redundant
        # probe bytes (its own writes already exercise the transport). nil until
        # the first write; treated as "idle since open" by #write_idle?.
        @last_write_at  = nil
        @mutex          = Mutex.new
        @cond           = ConditionVariable.new
      end

      # Account a claimed concurrency slot to this stream so #close releases it
      # exactly once. The public #stream helper claims the slot before parking.
      def slot_held!
        @slot_held = true
      end

      # Rack 3 streaming-body entry point. The server calls this exactly once.
      def call(stream)
        @stream = stream
        @back.call(self)
        park if @keep_open && !@closed
        @reason ||= :complete
      rescue *DISCONNECT_ERRORS, ClientDisconnected
        @reason = :disconnect
      rescue Exception => e
        # Genuine application error: notify the registered error handlers (so a
        # mid-stream crash is not invisible to Sentry/OpenTelemetry), tear the
        # stream down, then re-raise LOUD so it still reaches
        # handle_exception!/dump_errors! instead of a silent or truncated 200.
        @reason = :error
        notify_error_handlers(e)
        raise e
      ensure
        close # idempotent; waiters wake + callbacks fire exactly once
      end

      def <<(data)
        @stream.write(data.to_s)
        # Record the write so the idle heartbeat backs off: a stream that is
        # actively emitting events does not need an extra probe on top. A plain
        # monotonic-float assignment is atomic under the GVL, and the only
        # cross-fiber reader (#write_idle? in the parked loop) tolerates a stale
        # read by at most one poll, so no lock is needed here.
        @last_write_at = current_time
        self
      rescue *DISCONNECT_ERRORS
        # Peer vanished mid-write. Surface it as our sentinel so #call's rescue
        # tears down cleanly rather than letting a raw Errno escape user code.
        raise ClientDisconnected
      end

      # IO-like alias for <<. Lets code that expects an IO-ish sink (anything
      # calling #write) drive the stream unchanged.
      alias write <<

      # Explicitly flush whatever the server stream buffers. There is NO
      # auto-flush: at realistic SSE cadence both Puma and Falcon already
      # deliver each write as its own client read, and on those servers #flush
      # is a no-op (Falcon's stream #flush is empty; Puma writes a raw socket
      # with nothing buffered). This exists for API completeness, explicit
      # intent, and portability to a server that DOES buffer. Closed?-guarded,
      # tolerant of a stream without #flush, routes a mid-flush disconnect
      # through the same sentinel as <<, and returns self so it chains.
      def flush
        return self if @closed || @stream.nil?
        return self unless @stream.respond_to?(:flush)
        return self if @stream.respond_to?(:closed?) && @stream.closed?

        @stream.flush
        self
      rescue *DISCONNECT_ERRORS
        raise ClientDisconnected
      end

      # Write one spec-correct Server-Sent Event over <<. See Sinatra::Helpers
      # for the full SSE framing rationale.
      #
      #   out.sse({ token: 'hi' })                 # JSON-encoded data
      #   out.sse("line1\nline2", event: 'msg')    # multi-line + named event
      #   out.sse('resume', id: 42)                # resumable id (opt-in)
      #
      # data:        non-String is JSON-encoded; a String is sent verbatim,
      #              split on every "\n" into one `data:` line each (a trailing
      #              newline yields a trailing empty `data:` line, preserved).
      # event:/id:   optional; NUL/CR/LF stripped so they cannot inject extra
      #              SSE fields. id: is per-event opt-in and NEVER auto-generated.
      # retry_after: maps to the SSE `retry:` reconnection hint (ms); off unless
      #              given (Ruby's `retry` keyword cannot be a kwarg name).
      def sse(data, event: nil, id: nil, retry_after: nil)
        data = data.to_json unless data.is_a?(String)
        frame = +''
        # Chained << of frozen literals avoids building a throwaway interpolated
        # string per field.
        frame << 'event: ' << sse_scrub(event) << "\n" if event
        frame << 'id: ' << sse_scrub(id) << "\n" unless id.nil?
        frame << "retry: #{Integer(retry_after)}\n" unless retry_after.nil?
        # split("\n", -1) keeps trailing empties, so "a\n" -> ["a", ""] -> two
        # data: lines, preserving the author's trailing newline. Skip the split
        # (and its array) for the common single-line case.
        if data.include?("\n")
          data.split("\n", -1).each { |line| frame << 'data: ' << line << "\n" }
        else
          frame << 'data: ' << data << "\n"
        end
        # The mandatory blank line that terminates the event.
        frame << "\n"
        self << frame
      end

      # An SSE comment line (": ...\n\n"): invisible to EventSource clients yet a
      # real write on the wire, so apps use it as a proxy/idle keepalive. This is
      # the APP's keepalive, conceptually distinct from the internal disconnect
      # probe heartbeat (which Sinatra emits on its own; see #stream).
      def sse_comment(text = '')
        self << ": #{sse_scrub(text)}\n\n"
      end

      # reason is one of :complete, :disconnect, :error (defaults to
      # :disconnect for an out-of-band close, e.g. a server/h2 native reap).
      def close(reason = nil)
        cbs = nil
        @mutex.synchronize do
          return if @closed

          @closed    = true
          @reason  ||= reason || :disconnect
          cbs        = @callbacks
          @callbacks = []
          # The load-bearing line: wake a parked keep_open #call. This is what
          # makes server-close, cross-request #close, the reaper's EOF and
          # Falcon's h2 RST_STREAM all reap a parked stream instead of leaking
          # the worker thread/fiber forever.
          @cond.broadcast
        end
        release_slot
        begin
          @stream.close if @stream && !@stream.closed?
        rescue *DISCONNECT_ERRORS, IOError
          # already gone; nothing to flush
        end
        fire(cbs, @reason)
      end

      def callback(&block)
        return fire([block], @reason || :complete) if closed?

        @callbacks << block
      end

      alias errback callback

      def closed?
        @closed
      end

      private

      # Fire teardown callbacks with the teardown reason, back-compatibly: an
      # arity-0 callback gets no argument (old contract), an arity-1 (or splat)
      # callback gets the reason. A callback hitting a dead peer must not stop
      # later callbacks.
      def fire(callbacks, reason)
        callbacks.each do |c|
          c.arity.zero? ? c.call : c.call(reason)
        rescue *DISCONNECT_ERRORS, ClientDisconnected
          # a teardown callback hitting a dead peer must not stop later callbacks
        end
      end

      # Invoke the registered on_stream_error handlers with the producer
      # exception. A broken reporter must not block the others, and must never
      # mask the real exception (which #call re-raises after this returns).
      def notify_error_handlers(error)
        @error_handlers.each do |handler|
          handler.call(error)
        rescue StandardError
          # a broken error reporter must not swallow the real exception
        end
      end

      def release_slot
        return unless @slot_held

        @slot_held = false
        self.class.release_slot
      end

      # Strip NUL/CR/LF from an SSE field value so an id/event/comment cannot
      # smuggle in a newline and forge extra SSE fields or terminate the event
      # early. Coerced to String first so non-String ids (e.g. integers) work.
      def sse_scrub(value)
        string = value.to_s
        # #delete allocates even when nothing is removed, so skip it when the
        # value is already clean (a constant event name, a numeric id).
        string.match?(/[\u0000\r\n]/) ? string.delete("\u0000\r\n") : string
      end

      # Park a keep_open #call until something closes us. Timed wait so the
      # worker re-probes the peer even if no broadcast arrives (a bare
      # @cond.wait would leak the thread when the client vanishes silently).
      def park
        # Add up to 10% jitter so a fleet of streams opened together does not
        # all hit the TTL on the same tick and reconnect in a thundering herd.
        deadline = @ttl && (current_time + @ttl + (@ttl * 0.1 * rand))
        @mutex.synchronize do
          until @closed
            @cond.wait(@mutex, @poll) # woken by timeout OR #close's broadcast
            break if @closed

            if deadline && current_time >= deadline
              # TTL ceiling reached: treat as a disconnect-class teardown so the
              # idle/leaked connection is reaped rather than parked forever.
              @reason = :disconnect
              break
            end

            probe_disconnect!
          end
        end
      end

      def current_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      # Detect a vanished peer using whatever the server gives us:
      #   * Puma hijacks to a raw BasicSocket  -> MSG_PEEK (zero bytes on wire)
      #   * Falcon HTTP/1 exposes no raw socket on the callable-body stream ->
      #     the heartbeat write IS the probe (HTTP/1 only, and only once
      #     write-idle; see #write_probe? and #write_idle?)
      #   * Falcon HTTP/2 -> the protocol reaps a closed stream natively, so we
      #     emit nothing and rely on the broadcast/poll backstop.
      #
      # The MSG_PEEK path probes every poll regardless of writes: it puts zero
      # bytes on the wire, so there is nothing to suppress. The write-probe path
      # instead backs off while the application is actively writing, because each
      # out.write/out.sse already exercises the transport and would surface a
      # dead peer on its own; only an idle stream needs the synthetic heartbeat.
      #
      # Future work: the HTTP/1 write-probe exists only because async-http does
      # not yet surface peer disconnect on an idle streaming body. Once it reaps
      # an idle HTTP/1 stream natively (a server-delivered close hook), this
      # probe becomes dead weight and can be dropped, leaving the Puma MSG_PEEK
      # path untouched. Tracking upstream at
      # https://github.com/socketry/async-http/issues/224
      def probe_disconnect!
        if (io = raw_socket)
          raise ClientDisconnected if peer_gone_peek?(io)
        elsif write_probe? && write_idle?
          begin
            @stream.write(@heartbeat)
          rescue *DISCONNECT_ERRORS
            raise ClientDisconnected
          rescue IOError => e
            # Falcon surfaces "output closed" as a plain IOError from
            # protocol-http's stream.rb, not an errno. Match that ONE message,
            # ONLY on this write-path probe, never broadened to the app path.
            raise ClientDisconnected if e.message.include?('closed')

            raise
          end
        end
      end

      # The write-probe heartbeat is an HTTP/1-only workaround for Falcon's
      # IO-less stream. It runs only when ALL hold: a heartbeat byte string was
      # configured, the server stream is NOT a raw socket (Puma uses MSG_PEEK),
      # and the protocol is HTTP/1.x. On HTTP/2 and newer the protocol layer
      # reaps a closed stream natively, so the probe would be dead weight on the
      # wire; a nil/unknown protocol is treated as HTTP/1 (the safe default that
      # still probes).
      def write_probe?
        return false unless @heartbeat
        return false if raw_socket

        @protocol.nil? || @protocol.start_with?('HTTP/1')
      end

      # True when no successful application write has landed in the last poll
      # interval, i.e. the stream is quiet enough to warrant a synthetic
      # heartbeat. A stream that has never written (nil) is idle by definition.
      # The window is @poll so that a stream writing more often than once per
      # poll never accrues a probe (a write landing exactly @poll ago still
      # does), while a fully idle one still gets one heartbeat per poll.
      def write_idle?
        @last_write_at.nil? || (current_time - @last_write_at) >= @poll
      end

      def raw_socket
        @stream if @stream.is_a?(::BasicSocket)
      end

      # Bidi-safe, byte-exact: MSG_PEEK reads zero bytes off the wire, so SSE,
      # long-poll and duplex clients are all undisturbed. An empty peek on a
      # readable socket means EOF: the peer closed its write half.
      def peer_gone_peek?(io)
        # io.wait_readable(0) is the fiber-scheduler-aware equivalent of a
        # zero-timeout IO.select: it returns the IO when readable, nil when not,
        # so a not-yet-readable socket short-circuits as "still connected".
        return false unless io.wait_readable(0)

        # EOF peeks as nil or "" depending on platform/socket; both mean gone.
        peeked = io.recv(1, Socket::MSG_PEEK)
        peeked.nil? || peeked.empty?
      rescue *DISCONNECT_ERRORS
        true
      end
    end

    # SSE comment line. Invisible to EventSource clients (a line beginning with
    # ':' is a comment per the SSE spec) yet still a real write on the wire, so
    # it doubles as the Falcon disconnect probe. Used as the default keep_open
    # heartbeat ONLY for text/event-stream responses. See #stream.
    SSE_HEARTBEAT = ": \n"

    # Allows to start sending data to the client even though later parts of
    # the response body have not yet been generated.
    #
    # The keep_open parameter specifies whether the stream stays open after the
    # block returns (e.g. an SSE/long-poll endpoint that pushes later). When
    # false, Stream#close is called once the block finishes.
    #
    # Disconnect reaping of a parked keep_open stream is server-aware:
    #   * Puma hijacks to a raw BasicSocket -> a zero-byte MSG_PEEK EOF probe
    #     always detects a vanished client, regardless of heartbeat. Nothing is
    #     written to the wire, so binary/long-poll streams are never corrupted.
    #   * Falcon hands an IO-less stream -> there is no socket to peek, so the
    #     ONLY way to notice an abrupt disconnect on an idle stream is to attempt
    #     a write. That write puts bytes on the wire, so we only enable it by
    #     default when it is provably harmless: a true SSE response
    #     (text/event-stream), where the heartbeat is an invisible ': ' comment.
    #
    # For a non-SSE keep_open stream on Falcon we must NOT inject bytes silently
    # (it would corrupt an arbitrary binary/long-poll body), so the heartbeat is
    # off by default there; pass heartbeat: explicitly to opt in. poll: and ttl:
    # tune the re-probe interval and the hard parking ceiling.
    def stream(keep_open = false, heartbeat: :auto, poll: Stream::POLL, ttl: :default)
      current   = @params.dup
      heartbeat = default_heartbeat if heartbeat == :auto
      protocol  = request.env['SERVER_PROTOCOL'] if respond_to?(:request) && request
      # ttl: :default uses the configured global default (set :stream_keep_open_ttl);
      # ttl: nil opts a stream out of the ceiling; ttl: N tunes it per stream.
      ttl       = stream_keep_open_ttl if ttl == :default

      # A keep_open stream holds a worker thread/fiber for its whole lifetime, so
      # cap how many can be parked at once (per process). Past the cap, shed with
      # 503 + Retry-After instead of parking another one, so a flood of idle
      # connections cannot starve the worker pool. Plain (non keep_open) streams
      # finish promptly and are not counted.
      return shed_stream if keep_open && !claim_stream_slot

      # Braces (not do/end) so the producer block binds to Stream.new, not to
      # the enclosing #body call.
      stream = Stream.new(
        keep_open,
        heartbeat: heartbeat,
        poll: poll,
        ttl: ttl,
        protocol: protocol,
        error_handlers: stream_error_handlers
      ) { |out| with_params(current) { yield(out) } }
      stream.slot_held! if keep_open
      body stream
    end

    private

    # Registered on_stream_error handlers for this app, or none.
    def stream_error_handlers
      settings.respond_to?(:stream_error_handlers) ? settings.stream_error_handlers : []
    end

    def stream_max_concurrent
      settings.respond_to?(:stream_max_concurrent) ? settings.stream_max_concurrent : nil
    end

    # Global default keep_open ceiling, configurable via set :stream_keep_open_ttl.
    def stream_keep_open_ttl
      settings.respond_to?(:stream_keep_open_ttl) ? settings.stream_keep_open_ttl : Stream::KEEP_OPEN_TTL
    end

    def claim_stream_slot
      Stream.claim_slot(stream_max_concurrent)
    end

    # Shed an over-cap keep_open request with 503 + Retry-After.
    def shed_stream
      retry_after = settings.respond_to?(:stream_retry_after) ? settings.stream_retry_after : 5
      response['Retry-After'] = retry_after.to_s
      halt 503, 'Too many concurrent streams, please retry later.'
    end

    # The default keep_open heartbeat: an invisible SSE comment, enabled only for
    # a true text/event-stream response, where it is provably harmless (a line
    # beginning with ':' is ignored by EventSource clients). For any other
    # content type we return nil so no bytes are ever injected into an arbitrary
    # binary/long-poll body. The protocol gating (skip the write-probe on HTTP/2,
    # where the protocol reaps natively) and the not-a-BasicSocket gating (Puma
    # uses MSG_PEEK) both live in Stream#write_probe?, so this only decides "is
    # this an SSE body that may carry an invisible comment". start_with? (not
    # include?) so a spoofed 'x-text/event-stream' type cannot trip it.
    def default_heartbeat
      ct = response['content-type'] || response['Content-Type']
      SSE_HEARTBEAT if ct.to_s.start_with?('text/event-stream')
    end

    public

    # Specify response freshness policy for HTTP caches (Cache-Control header).
    # Any number of non-value directives (:public, :private, :no_cache,
    # :no_store, :must_revalidate, :proxy_revalidate) may be passed along with
    # a Hash of value directives (:max_age, :s_maxage).
    #
    #   cache_control :public, :must_revalidate, :max_age => 60
    #   => Cache-Control: public, must-revalidate, max-age=60
    #
    # See RFC 2616 / 14.9 for more on standard cache control directives:
    # http://tools.ietf.org/html/rfc2616#section-14.9.1
    def cache_control(*values)
      if values.last.is_a?(Hash)
        hash = values.pop
        hash.reject! { |_k, v| v == false }
        hash.reject! { |k, v| values << k if v == true }
      else
        hash = {}
      end

      values.map! { |value| value.to_s.tr('_', '-') }
      hash.each do |key, value|
        key = key.to_s.tr('_', '-')
        value = value.to_i if %w[max-age s-maxage].include? key
        values << "#{key}=#{value}"
      end

      response['Cache-Control'] = values.join(', ') if values.any?
    end

    # Set the Expires header and Cache-Control/max-age directive. Amount
    # can be an integer number of seconds in the future or a Time object
    # indicating when the response should be considered "stale". The remaining
    # "values" arguments are passed to the #cache_control helper:
    #
    #   expires 500, :public, :must_revalidate
    #   => Cache-Control: public, must-revalidate, max-age=500
    #   => Expires: Mon, 08 Jun 2009 08:50:17 GMT
    #
    def expires(amount, *values)
      values << {} unless values.last.is_a?(Hash)

      if amount.is_a? Integer
        time    = Time.now + amount.to_i
        max_age = amount
      else
        time    = time_for amount
        max_age = time - Time.now
      end

      values.last.merge!(max_age: max_age) { |_key, v1, v2| v1 || v2 }
      cache_control(*values)

      response['Expires'] = time.httpdate
    end

    # Set the last modified time of the resource (HTTP 'Last-Modified' header)
    # and halt if conditional GET matches. The +time+ argument is a Time,
    # DateTime, or other object that responds to +to_time+.
    #
    # When the current request includes an 'If-Modified-Since' header that is
    # equal or later than the time specified, execution is immediately halted
    # with a '304 Not Modified' response.
    def last_modified(time)
      return unless time

      time = time_for time
      response['Last-Modified'] = time.httpdate
      return if env['HTTP_IF_NONE_MATCH']

      if (status == 200) && env['HTTP_IF_MODIFIED_SINCE']
        # compare based on seconds since epoch
        since = Time.httpdate(env['HTTP_IF_MODIFIED_SINCE']).to_i
        halt 304 if since >= time.to_i
      end

      if (success? || (status == 412)) && env['HTTP_IF_UNMODIFIED_SINCE']
        # compare based on seconds since epoch
        since = Time.httpdate(env['HTTP_IF_UNMODIFIED_SINCE']).to_i
        halt 412 if since < time.to_i
      end
    rescue ArgumentError
    end

    ETAG_KINDS = %i[strong weak].freeze
    # Set the response entity tag (HTTP 'ETag' header) and halt if conditional
    # GET matches. The +value+ argument is an identifier that uniquely
    # identifies the current version of the resource. The +kind+ argument
    # indicates whether the etag should be used as a :strong (default) or :weak
    # cache validator.
    #
    # When the current request includes an 'If-None-Match' header with a
    # matching etag, execution is immediately halted. If the request method is
    # GET or HEAD, a '304 Not Modified' response is sent.
    def etag(value, options = {})
      # Before touching this code, please double check RFC 2616 14.24 and 14.26.
      options      = { kind: options } unless Hash === options
      kind         = options[:kind] || :strong
      new_resource = options.fetch(:new_resource) { request.post? }

      unless ETAG_KINDS.include?(kind)
        raise ArgumentError, ':strong or :weak expected'
      end

      value = format('"%s"', value)
      value = "W/#{value}" if kind == :weak
      response['ETag'] = value

      return unless success? || status == 304

      if etag_matches?(env['HTTP_IF_NONE_MATCH'], new_resource)
        halt(request.safe? ? 304 : 412)
      end

      if env['HTTP_IF_MATCH']
        return if etag_matches?(env['HTTP_IF_MATCH'], new_resource)

        halt 412
      end

      nil
    end

    # Sugar for redirect (example:  redirect back)
    def back
      request.referer
    end

    # whether or not the status is set to 1xx
    def informational?
      status.between? 100, 199
    end

    # whether or not the status is set to 2xx
    def success?
      status.between? 200, 299
    end

    # whether or not the status is set to 3xx
    def redirect?
      status.between? 300, 399
    end

    # whether or not the status is set to 4xx
    def client_error?
      status.between? 400, 499
    end

    # whether or not the status is set to 5xx
    def server_error?
      status.between? 500, 599
    end

    # whether or not the status is set to 404
    def not_found?
      status == 404
    end

    # whether or not the status is set to 400
    def bad_request?
      status == 400
    end

    # Generates a Time object from the given value.
    # Used by #expires and #last_modified.
    def time_for(value)
      if value.is_a? Numeric
        Time.at value
      elsif value.respond_to? :to_s
        Time.parse value.to_s
      else
        value.to_time
      end
    rescue ArgumentError => e
      raise e
    rescue Exception
      raise ArgumentError, "unable to convert #{value.inspect} to a Time object"
    end

    private

    # Helper method checking if a ETag value list includes the current ETag.
    def etag_matches?(list, new_resource = request.post?)
      return !new_resource if list == '*'

      list.to_s.split(',').map(&:strip).include?(response['ETag'])
    end

    def with_params(temp_params)
      original = @params
      @params = temp_params
      yield
    ensure
      @params = original if original
    end

    # Drop any hand-set Content-Length on a streaming/callable-body response.
    #
    # SECURITY (response splitting / desync): under Rack 3 the SERVER owns
    # framing for a streaming body (Rack::Chunked was removed; Puma/Falcon emit
    # chunked or close-delimited framing themselves). A Content-Length the app
    # set by hand cannot be honoured by Sinatra; it no longer counts the bytes,
    # so if the streamed body is shorter the connection hangs waiting for the
    # promised bytes, and if it is longer the surplus bytes bleed into the next
    # response on a keep-alive socket: classic response splitting. Stripping it
    # here is the spec-correct framing behaviour, not an app-error swallow, so a
    # silent strip is the right call (no app intent is being second-guessed,
    # the header is simply not the app's to set on a stream under Rack 3).
    #
    # Scoped narrowly to the streaming path on purpose: dentarg removed
    # over-eager Content-Length deletion in a39c0c92 (Rack::Files), so we do NOT
    # touch the header on any non-streaming response. Lowercase per Rack 3.
    def strip_streaming_content_length!
      headers.delete 'content-length'
    end
  end

  # Template rendering methods. Each method takes the name of a template
  # to render as a Symbol and returns a String with the rendered output,
  # as well as an optional hash with additional options.
  #
  # `template` is either the name or path of the template as symbol
  # (Use `:'subdir/myview'` for views in subdirectories), or a string
  # that will be rendered.
  #
  # Possible options are:
  #   :content_type   The content type to use, same arguments as content_type.
  #   :layout         If set to something falsy, no layout is rendered, otherwise
  #                   the specified layout is used (Ignored for `sass`)
  #   :layout_engine  Engine to use for rendering the layout.
  #   :locals         A hash with local variables that should be available
  #                   in the template
  #   :scope          If set, template is evaluate with the binding of the given
  #                   object rather than the application instance.
  #   :views          Views directory to use.
  module Templates
    module ContentTyped
      attr_accessor :content_type
    end

    def initialize
      super
      @default_layout = :layout
      @preferred_extension = nil
    end

    def erb(template, options = {}, locals = {}, &block)
      render(:erb, template, options, locals, &block)
    end

    def haml(template, options = {}, locals = {}, &block)
      render(:haml, template, options, locals, &block)
    end

    def sass(template, options = {}, locals = {})
      options[:default_content_type] = :css
      options[:exclude_outvar] = true
      options[:layout] = nil
      render :sass, template, options, locals
    end

    def scss(template, options = {}, locals = {})
      options[:default_content_type] = :css
      options[:exclude_outvar] = true
      options[:layout] = nil
      render :scss, template, options, locals
    end

    def builder(template = nil, options = {}, locals = {}, &block)
      options[:default_content_type] = :xml
      render_ruby(:builder, template, options, locals, &block)
    end

    def liquid(template, options = {}, locals = {}, &block)
      render(:liquid, template, options, locals, &block)
    end

    def markdown(template, options = {}, locals = {})
      options[:exclude_outvar] = true
      render :markdown, template, options, locals
    end

    def rdoc(template, options = {}, locals = {})
      render :rdoc, template, options, locals
    end

    def asciidoc(template, options = {}, locals = {})
      render :asciidoc, template, options, locals
    end

    def markaby(template = nil, options = {}, locals = {}, &block)
      render_ruby(:mab, template, options, locals, &block)
    end

    def nokogiri(template = nil, options = {}, locals = {}, &block)
      options[:default_content_type] = :xml
      render_ruby(:nokogiri, template, options, locals, &block)
    end

    def slim(template, options = {}, locals = {}, &block)
      render(:slim, template, options, locals, &block)
    end

    def yajl(template, options = {}, locals = {})
      options[:default_content_type] = :json
      render :yajl, template, options, locals
    end

    def rabl(template, options = {}, locals = {})
      Rabl.register!
      render :rabl, template, options, locals
    end

    # Calls the given block for every possible template file in views,
    # named name.ext, where ext is registered on engine.
    def find_template(views, name, engine)
      yield ::File.join(views, "#{name}.#{@preferred_extension}")

      Tilt.default_mapping.extensions_for(engine).each do |ext|
        yield ::File.join(views, "#{name}.#{ext}") unless ext == @preferred_extension
      end
    end

    private

    # logic shared between builder and nokogiri
    def render_ruby(engine, template, options = {}, locals = {}, &block)
      if template.is_a?(Hash)
        options = template
        template = nil
      end
      template = proc { block } if template.nil?
      render engine, template, options, locals
    end

    def render(engine, data, options = {}, locals = {}, &block)
      # merge app-level options
      engine_options = settings.respond_to?(engine) ? settings.send(engine) : {}
      options.merge!(engine_options) { |_key, v1, _v2| v1 }

      # extract generic options
      locals          = options.delete(:locals) || locals         || {}
      views           = options.delete(:views)  || settings.views || './views'
      layout          = options[:layout]
      layout          = false if layout.nil? && options.include?(:layout)
      eat_errors      = layout.nil?
      layout          = engine_options[:layout] if layout.nil? || (layout == true && engine_options[:layout] != false)
      layout          = @default_layout         if layout.nil? || (layout == true)
      layout_options  = options.delete(:layout_options) || {}
      content_type    = options.delete(:default_content_type)
      content_type    = options.delete(:content_type)   || content_type
      layout_engine   = options.delete(:layout_engine)  || engine
      scope           = options.delete(:scope)          || self
      exclude_outvar  = options.delete(:exclude_outvar)
      options.delete(:layout)

      # set some defaults
      options[:outvar] ||= '@_out_buf' unless exclude_outvar
      options[:default_encoding] ||= settings.default_encoding

      # compile and render template
      begin
        layout_was      = @default_layout
        @default_layout = false
        template        = compile_template(engine, data, options, views)
        output          = template.render(scope, locals, &block)
      ensure
        @default_layout = layout_was
      end

      # render layout
      if layout
        extra_options = { views: views, layout: false, eat_errors: eat_errors, scope: scope }
        options = options.merge(extra_options).merge!(layout_options)

        catch(:layout_missing) { return render(layout_engine, layout, options, locals) { output } }
      end

      if content_type
        # sass-embedded returns a frozen string
        output = +output
        output.extend(ContentTyped).content_type = content_type
      end
      output
    end

    def compile_template(engine, data, options, views)
      eat_errors = options.delete :eat_errors
      template = Tilt[engine]
      raise "Template engine not found: #{engine}" if template.nil?

      case data
      when Symbol
        template_cache.fetch engine, data, options, views do
          body, path, line = settings.templates[data]
          if body
            body = body.call if body.respond_to?(:call)
            template.new(path, line.to_i, options) { body }
          else
            found = false
            @preferred_extension = engine.to_s
            find_template(views, data, template) do |file|
              path ||= file # keep the initial path rather than the last one
              found = File.exist?(file)
              if found
                path = file
                break
              end
            end
            throw :layout_missing if eat_errors && !found
            template.new(path, 1, options)
          end
        end
      when Proc
        compile_block_template(template, options, &data)
      when String
        template_cache.fetch engine, data, options, views do
          compile_block_template(template, options) { data }
        end
      else
        raise ArgumentError, "Sorry, don't know how to render #{data.inspect}."
      end
    end

    def compile_block_template(template, options, &body)
      first_location = caller_locations.first
      path = first_location.path
      line = first_location.lineno
      path = options[:path] || path
      line = options[:line] || line
      template.new(path, line.to_i, options, &body)
    end
  end

  # Extremely simple template cache implementation.
  #   * Not thread-safe.
  #   * Size is unbounded.
  #   * Keys are not copied defensively, and should not be modified after
  #     being passed to #fetch.  More specifically, the values returned by
  #     key#hash and key#eql? should not change.
  #
  # Implementation copied from Tilt::Cache.
  class TemplateCache
    def initialize
      @cache = {}
    end

    # Caches a value for key, or returns the previously cached value.
    # If a value has been previously cached for key then it is
    # returned. Otherwise, block is yielded to and its return value
    # which may be nil, is cached under key and returned.
    def fetch(*key)
      @cache.fetch(key) do
        @cache[key] = yield
      end
    end

    # Clears the cache.
    def clear
      @cache = {}
    end
  end

  # Base class for all Sinatra applications and middleware.
  class Base
    include Rack::Utils
    include Helpers
    include Templates

    URI_INSTANCE = defined?(URI::RFC2396_PARSER) ? URI::RFC2396_PARSER : URI::RFC2396_Parser.new

    attr_accessor :app, :env, :request, :response, :params
    attr_reader   :template_cache

    def initialize(app = nil, **_kwargs)
      super()
      @app = app
      @template_cache = TemplateCache.new
      @pinned_response = nil # whether a before! filter pinned the content-type
      yield self if block_given?
    end

    # Rack call interface.
    def call(env)
      dup.call!(env)
    end

    def call!(env) # :nodoc:
      @env      = env
      @params   = IndifferentHash.new
      @request  = Request.new(env)
      @response = Response.new
      @pinned_response = nil
      template_cache.clear if settings.reload_templates

      invoke { dispatch! }
      invoke { error_block!(response.status) } unless @env['sinatra.error']

      unless @response['content-type']
        if Array === body && body[0].respond_to?(:content_type)
          content_type body[0].content_type
        elsif (default = settings.default_content_type)
          content_type default
        end
      end

      @response.finish
    end

    # Access settings defined with Base.set.
    def self.settings
      self
    end

    # Access settings defined with Base.set.
    def settings
      self.class.settings
    end

    # Exit the current block, halts any further processing
    # of the request, and returns the specified response.
    def halt(*response)
      response = response.first if response.length == 1
      throw :halt, response
    end

    # Pass control to the next matching route.
    # If there are no more matching routes, Sinatra will
    # return a 404 response.
    def pass(&block)
      throw :pass, block
    end

    # Forward the request to the downstream app -- middleware only.
    def forward
      raise 'downstream app not set' unless @app.respond_to? :call

      status, headers, body = @app.call env
      @response.status = status
      @response.body = body
      @response.headers.merge! headers
      nil
    end

    private

    # Run filters defined on the class and all superclasses.
    # Accepts an optional block to call after each filter is applied.
    def filter!(type, base = settings, &block)
      filter!(type, base.superclass, &block) if base.superclass.respond_to?(:filters)
      base.filters[type].each do |args|
        result = process_route(*args)
        block.call(result) if block_given?
      end
    end

    # Run routes defined on the class and all superclasses.
    def route!(base = settings, pass_block = nil)
      routes = base.routes[@request.request_method]

      routes&.each do |pattern, conditions, block|
        response.delete_header('content-type') unless @pinned_response

        returned_pass_block = process_route(pattern, conditions) do |*args|
          env['sinatra.route'] = "#{@request.request_method} #{pattern}"
          route_eval { block[*args] }
        end

        # don't wipe out pass_block in superclass
        pass_block = returned_pass_block if returned_pass_block
      end

      # Run routes defined in superclass.
      if base.superclass.respond_to?(:routes)
        return route!(base.superclass, pass_block)
      end

      route_eval(&pass_block) if pass_block
      route_missing
    end

    # Run a route block and throw :halt with the result.
    def route_eval
      throw :halt, yield
    end

    # If the current request matches pattern and conditions, fill params
    # with keys and call the given block.
    # Revert params afterwards.
    #
    # Returns pass block.
    def process_route(pattern, conditions, block = nil, values = [])
      route = @request.path_info
      route = '/' if route.empty? && !settings.empty_path_info?
      route = route[0..-2] if !settings.strict_paths? && route != '/' && route.end_with?('/')

      params = pattern.params(route)
      return unless params

      params.delete('ignore') # TODO: better params handling, maybe turn it into "smart" object or detect changes
      force_encoding(params)
      @params = @params.merge(params) { |_k, v1, v2| v2 || v1 } if params.any?

      regexp_exists = pattern.is_a?(Mustermann::Regular) || (pattern.respond_to?(:patterns) && pattern.patterns.any? { |subpattern| subpattern.is_a?(Mustermann::Regular) })
      if regexp_exists
        captures           = pattern.match(route).captures.map { |c| URI_INSTANCE.unescape(c) if c }
        values            += captures
        @params[:captures] = force_encoding(captures) unless captures.nil? || captures.empty?
      else
        values += params.values.flatten
      end

      catch(:pass) do
        conditions.each { |c| throw :pass if c.bind(self).call == false }
        block ? block[self, values] : yield(self, values)
      end
    rescue StandardError
      @env['sinatra.error.params'] = @params
      raise
    ensure
      params ||= {}
      params.each { |k, _| @params.delete(k) } unless @env['sinatra.error.params']
    end

    # No matching route was found or all routes passed. The default
    # implementation is to forward the request downstream when running
    # as middleware (@app is non-nil); when no downstream app is set, raise
    # a NotFound exception. Subclasses can override this method to perform
    # custom route miss logic.
    def route_missing
      raise NotFound unless @app

      forward
    end

    # Attempt to serve static files from public directory. Throws :halt when
    # a matching file is found, returns nil otherwise.
    # If custom static headers are defined, use them.
    def static!(options = {})
      return if (public_dir = settings.public_folder).nil?

      path = "#{public_dir}#{URI_INSTANCE.unescape(request.path_info)}"
      return unless valid_path?(path)

      path = File.expand_path(path)
      return unless path.start_with?("#{File.expand_path(public_dir)}/")

      return unless File.file?(path)

      env['sinatra.static_file'] = path
      cache_control(*settings.static_cache_control) if settings.static_cache_control?

      headers(settings.static_headers) if settings.static_headers?

      send_file path, options.merge(disposition: nil)
    end

    # Run the block with 'throw :halt' support and apply result to the response.
    def invoke(&block)
      res = catch(:halt, &block)

      res = [res] if (Integer === res) || (String === res)
      if (Array === res) && (Integer === res.first)
        res = res.dup
        status(res.shift)
        body(res.pop)
        headers(*res)
      elsif res.respond_to?(:each) ||
            (res.respond_to?(:call) && (!res.respond_to?(:arity) || res.arity != 0))
        # Besides an Enumerable body (responds to #each), also emit a bare Rack 3
        # streaming body (U2): an arity-1 callable that takes the server stream.
        # Such a body used to fall through every branch here and be silently
        # dropped to an empty 200. The arity guard mirrors Helpers#body so an
        # arity-0 callable (which #body treats as a deferred enumerable producer)
        # is not misrouted here.
        body res
      end
      nil # avoid double setting the same response tuple twice
    end

    # Dispatch a request with error handling.
    def dispatch!
      # Avoid passing frozen string in force_encoding
      @params.merge!(@request.params).each do |key, val|
        next unless val.respond_to?(:force_encoding)

        val = val.dup if val.frozen?
        @params[key] = force_encoding(val)
      end

      invoke do
        static! if settings.static? && (request.get? || request.head?)
        filter! :before do
          @pinned_response = !response['content-type'].nil?
        end
        route!
      end
    rescue ::Exception => e
      invoke { handle_exception!(e) }
    ensure
      begin
        filter! :after unless env['sinatra.static_file']
      rescue ::Exception => e
        invoke { handle_exception!(e) } unless @env['sinatra.error']
      end
    end

    # Error handling during requests.
    def handle_exception!(boom)
      error_params = @env['sinatra.error.params']

      @params = @params.merge(error_params) if error_params

      @env['sinatra.error'] = boom

      http_status = if boom.is_a? Sinatra::Error
                      if boom.respond_to? :http_status
                        boom.http_status
                      elsif settings.use_code? && boom.respond_to?(:code)
                        boom.code
                      end
                    end

      http_status = 500 unless http_status&.between?(400, 599)
      status(http_status)

      if server_error?
        dump_errors! boom if settings.dump_errors?
        raise boom if settings.show_exceptions? && (settings.show_exceptions != :after_handler)
      elsif not_found?
        headers['X-Cascade'] = 'pass' if settings.x_cascade?
      end

      if (res = error_block!(boom.class, boom) || error_block!(status, boom))
        return res
      end

      if not_found? || bad_request?
        if boom.message && boom.message != boom.class.name
          body Rack::Utils.escape_html(boom.message)
        else
          content_type 'text/html'
          body "<h1>#{not_found? ? 'Not Found' : 'Bad Request'}</h1>"
        end
      end

      return unless server_error?

      raise boom if settings.raise_errors? || settings.show_exceptions?

      error_block! Exception, boom
    end

    # Find an custom error block for the key(s) specified.
    def error_block!(key, *block_params)
      base = settings
      while base.respond_to?(:errors)
        args_array = base.errors[key]

        next base = base.superclass unless args_array

        args_array.reverse_each do |args|
          first = args == args_array.first
          args += [block_params]
          resp = process_route(*args)
          return resp unless resp.nil? && !first
        end
      end
      return false unless key.respond_to?(:superclass) && (key.superclass < Exception)

      error_block!(key.superclass, *block_params)
    end

    def dump_errors!(boom)
      if boom.respond_to?(:detailed_message)
        msg = boom.detailed_message(highlight: false)
        if msg =~ /\A(.*?)(?: \(#{ Regexp.quote(boom.class.to_s) }\))?\n/
          msg = $1
          additional_msg = $'.lines(chomp: true)
        else
          additional_msg = []
        end
      else
        msg = boom.message
        additional_msg = []
      end
      msg = ["#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} - #{boom.class} - #{msg}:", *additional_msg, *boom.backtrace].join("\n\t")
      @env['rack.errors'].puts(msg)
    end

    class << self
      CALLERS_TO_IGNORE = [ # :nodoc:
        %r{/sinatra(/(base|main|show_exceptions))?\.rb$},   # all sinatra code
        %r{lib/tilt.*\.rb$},                                # all tilt code
        /^\(.*\)$/,                                         # generated code
        /\/bundled_gems.rb$/,                               # ruby >= 3.3 with bundler >= 2.5
        %r{rubygems/(custom|core_ext/kernel)_require\.rb$}, # rubygems require hacks
        /active_support/,                                   # active_support require hacks
        %r{bundler(/(?:runtime|inline))?\.rb},              # bundler require hacks
        /<internal:/,                                       # internal in ruby >= 1.9.2
        %r{zeitwerk/(core_ext/)?kernel\.rb}                 # Zeitwerk kernel#require decorator
      ].freeze

      attr_reader :routes, :filters, :templates, :errors, :on_start_callback, :on_stop_callback

      def callers_to_ignore
        CALLERS_TO_IGNORE
      end

      # Removes all routes, filters, middleware and extension hooks from the
      # current class (not routes/filters/... defined by its superclass).
      def reset!
        @conditions     = []
        @routes         = {}
        @filters        = { before: [], after: [] }
        @errors         = {}
        @middleware     = []
        @prototype      = nil
        @extensions     = []

        @templates = if superclass.respond_to?(:templates)
                       Hash.new { |_hash, key| superclass.templates[key] }
                     else
                       {}
                     end
      end

      # Extension modules registered on this class and all superclasses.
      def extensions
        if superclass.respond_to?(:extensions)
          (@extensions + superclass.extensions).uniq
        else
          @extensions
        end
      end

      # Middleware used in this class and all superclasses.
      def middleware
        if superclass.respond_to?(:middleware)
          superclass.middleware + @middleware
        else
          @middleware
        end
      end

      # Sets an option to the given value.  If the value is a proc,
      # the proc will be called every time the option is accessed.
      def set(option, value = (not_set = true), ignore_setter = false, &block)
        raise ArgumentError if block && !not_set

        if block
          value = block
          not_set = false
        end

        if not_set
          raise ArgumentError unless option.respond_to?(:each)

          option.each { |k, v| set(k, v) }
          return self
        end

        if respond_to?("#{option}=") && !ignore_setter
          return __send__("#{option}=", value)
        end

        setter = proc { |val| set option, val, true }
        getter = proc { value }

        case value
        when Proc
          getter = value
        when Symbol, Integer, FalseClass, TrueClass, NilClass
          getter = value.inspect
        when Hash
          setter = proc do |val|
            val = value.merge val if Hash === val
            set option, val, true
          end
        end

        define_singleton("#{option}=", setter)
        define_singleton(option, getter)
        define_singleton("#{option}?", "!!#{option}") unless method_defined? "#{option}?"
        self
      end

      # Same as calling `set :option, true` for each of the given options.
      def enable(*opts)
        opts.each { |key| set(key, true) }
      end

      # Same as calling `set :option, false` for each of the given options.
      def disable(*opts)
        opts.each { |key| set(key, false) }
      end

      # Define a custom error handler. Optionally takes either an Exception
      # class, or an HTTP status code to specify which errors should be
      # handled.
      def error(*codes, &block)
        args  = compile! 'ERROR', /.*/, block
        codes = codes.flat_map(&method(:Array))
        codes << Exception if codes.empty?
        codes << Sinatra::NotFound if codes.include?(404)
        codes.each { |c| (@errors[c] ||= []) << args }
      end

      # Sugar for `error(404) { ... }`
      def not_found(&block)
        error(404, &block)
      end

      # Register a handler invoked when a streaming producer block raises
      # mid-stream. A mid-stream exception is invisible to the normal error
      # channels (error blocks, dump_errors, Rack error middleware) because the
      # Rack triple was already returned before the body ran, so this is the one
      # place to report it (Sentry, OpenTelemetry, ...). The exception still
      # propagates after every handler runs.
      #
      #   on_stream_error { |e| Sentry.capture_exception(e) }
      def on_stream_error(&block)
        # Dup so appending to a subclass never mutates the parent's array.
        set :stream_error_handlers, stream_error_handlers + [block]
      end

      # Define a named template. The block must return the template source.
      def template(name, &block)
        filename, line = caller_locations.first
        templates[name] = [block, filename, line.to_i]
      end

      # Define the layout template. The block must return the template source.
      def layout(name = :layout, &block)
        template name, &block
      end

      # Load embedded templates from the file; uses the caller's __FILE__
      # when no file is specified.
      def inline_templates=(file = nil)
        file = (caller_files.first || File.expand_path($0)) if file.nil? || file == true

        begin
          io = ::IO.respond_to?(:binread) ? ::IO.binread(file) : ::IO.read(file)
          app, data = io.gsub("\r\n", "\n").split(/^__END__$/, 2)
        rescue Errno::ENOENT
          app, data = nil
        end

        return unless data

        encoding = if app && app =~ /([^\n]*\n)?#[^\n]*coding: *(\S+)/m
                     $2
                   else
                     settings.default_encoding
                   end

        lines = app.count("\n") + 1
        template = nil
        force_encoding data, encoding
        data.each_line do |line|
          lines += 1
          if line =~ /^@@\s*(.*\S)\s*$/
            template = force_encoding(String.new, encoding)
            templates[$1.to_sym] = [template, file, lines]
          elsif template
            template << line
          end
        end
      end

      # Lookup or register a mime type in Rack's mime registry.
      def mime_type(type, value = nil)
        return type      if type.nil?
        return type.to_s if type.to_s.include?('/')

        type = ".#{type}" unless type.to_s[0] == '.'
        return Rack::Mime.mime_type(type, nil) unless value

        Rack::Mime::MIME_TYPES[type] = value
      end

      # provides all mime types matching type, including deprecated types:
      #   mime_types :html # => ['text/html']
      #   mime_types :js   # => ['application/javascript', 'text/javascript']
      def mime_types(type)
        type = mime_type type
        if type =~ %r{^application/(xml|javascript)$}
          [type, "text/#{$1}"]
        elsif type =~ %r{^text/(xml|javascript)$}
          [type, "application/#{$1}"]
        else
          [type]
        end
      end

      # Define a before filter; runs before all requests within the same
      # context as route handlers and may access/modify the request and
      # response.
      def before(path = /.*/, **options, &block)
        add_filter(:before, path, **options, &block)
      end

      # Define an after filter; runs after all requests within the same
      # context as route handlers and may access/modify the request and
      # response.
      def after(path = /.*/, **options, &block)
        add_filter(:after, path, **options, &block)
      end

      # add a filter
      def add_filter(type, path = /.*/, **options, &block)
        filters[type] << compile!(type, path, block, **options)
      end

      def on_start(&on_start_callback)
        @on_start_callback = on_start_callback
      end

      def on_stop(&on_stop_callback)
        @on_stop_callback = on_stop_callback
      end

      # Add a route condition. The route is considered non-matching when the
      # block returns false.
      def condition(name = "#{caller.first[/`.*'/]} condition", &block)
        @conditions << generate_method(name, &block)
      end

      def public=(value)
        warn_for_deprecation ':public is no longer used to avoid overloading Module#public, use :public_folder or :public_dir instead'
        set(:public_folder, value)
      end

      def public_dir=(value)
        self.public_folder = value
      end

      def public_dir
        public_folder
      end

      # Defining a `GET` handler also automatically defines
      # a `HEAD` handler.
      def get(path, opts = {}, &block)
        conditions = @conditions.dup
        route('GET', path, opts, &block)

        @conditions = conditions
        route('HEAD', path, opts, &block)
      end

      def put(path, opts = {}, &block)     route 'PUT',     path, opts, &block end

      def post(path, opts = {}, &block)    route 'POST',    path, opts, &block end

      def delete(path, opts = {}, &block)  route 'DELETE',  path, opts, &block end

      def head(path, opts = {}, &block)    route 'HEAD',    path, opts, &block end

      def options(path, opts = {}, &block) route 'OPTIONS', path, opts, &block end

      def patch(path, opts = {}, &block)   route 'PATCH',   path, opts, &block end

      def link(path, opts = {}, &block)    route 'LINK',    path, opts, &block end

      def unlink(path, opts = {}, &block)  route 'UNLINK',  path, opts, &block end

      # Makes the methods defined in the block and in the Modules given
      # in `extensions` available to the handlers and templates
      def helpers(*extensions, &block)
        class_eval(&block)   if block_given?
        include(*extensions) if extensions.any?
      end

      # Register an extension. Alternatively take a block from which an
      # extension will be created and registered on the fly.
      def register(*extensions, &block)
        extensions << Module.new(&block) if block_given?
        @extensions += extensions
        extensions.each do |extension|
          extend extension
          extension.registered(self) if extension.respond_to?(:registered)
        end
      end

      def development?; environment == :development end
      def production?;  environment == :production  end
      def test?;        environment == :test        end

      # Set configuration options for Sinatra and/or the app.
      # Allows scoping of settings for certain environments.
      def configure(*envs)
        yield self if envs.empty? || envs.include?(environment.to_sym)
      end

      # Use the specified Rack middleware
      def use(middleware, *args, &block)
        @prototype = nil
        @middleware << [middleware, args, block]
      end
      ruby2_keywords(:use) if respond_to?(:ruby2_keywords, true)

      # Stop the self-hosted server if running.
      def quit!
        return unless running?

        # Use Thin's hard #stop! if available, otherwise just #stop.
        running_server.respond_to?(:stop!) ? running_server.stop! : running_server.stop
        warn '== Sinatra has ended his set (crowd applauds)' unless suppress_messages?
        set :running_server, nil
        set :handler_name, nil

        on_stop_callback.call unless on_stop_callback.nil?
      end

      alias stop! quit!

      # Run the Sinatra app as a self-hosted server using
      # Puma, Falcon (in that order). If given a block, will call
      # with the constructed handler once we have taken the stage.
      def run!(options = {}, &block)
        unless defined?(Rackup::Handler)
          rackup_warning = <<~MISSING_RACKUP
            Sinatra could not start, the required gems weren't found!

            Add them to your bundle with:

                bundle add rackup puma

            or install them with:

                gem install rackup puma

          MISSING_RACKUP
          warn rackup_warning
          exit 1
        end

        return if running?

        set options
        handler         = Rackup::Handler.pick(server)
        handler_name    = handler.name.gsub(/.*::/, '')
        server_settings = settings.respond_to?(:server_settings) ? settings.server_settings : {}
        server_settings.merge!(Port: port, Host: bind)

        begin
          start_server(handler, server_settings, handler_name, &block)
        rescue Errno::EADDRINUSE
          warn "== Someone is already performing on port #{port}!"
          raise
        ensure
          quit!
        end
      end

      alias start! run!

      # Check whether the self-hosted server is running or not.
      def running?
        running_server?
      end

      # The prototype instance used to process requests.
      def prototype
        @prototype ||= new
      end

      # Create a new instance without middleware in front of it.
      alias new! new unless method_defined? :new!

      # Create a new instance of the class fronted by its middleware
      # pipeline. The object is guaranteed to respond to #call but may not be
      # an instance of the class new was called on.
      def new(*args, &block)
        instance = new!(*args, &block)
        Wrapper.new(build(instance).to_app, instance)
      end
      ruby2_keywords :new if respond_to?(:ruby2_keywords, true)

      # Creates a Rack::Builder instance with all the middleware set up and
      # the given +app+ as end point.
      def build(app)
        builder = Rack::Builder.new
        setup_default_middleware builder
        setup_middleware builder
        builder.run app
        builder
      end

      def call(env)
        synchronize { prototype.call(env) }
      end

      # Like Kernel#caller but excluding certain magic entries and without
      # line / method information; the resulting array contains filenames only.
      def caller_files
        cleaned_caller(1).flatten
      end

      private

      # Starts the server by running the Rack Handler.
      def start_server(handler, server_settings, handler_name)
        # Ensure we initialize middleware before startup, to match standard Rack
        # behavior, by ensuring an instance exists:
        prototype
        # Run the instance we created:
        handler.run(self, **server_settings) do |server|
          unless suppress_messages?
            warn "== Sinatra (v#{Sinatra::VERSION}) has taken the stage on #{port} for #{environment} with backup from #{handler_name}"
          end

          setup_traps
          set :running_server, server
          set :handler_name,   handler_name
          server.threaded = settings.threaded if server.respond_to? :threaded=
          on_start_callback.call unless on_start_callback.nil?
          yield server if block_given?
        end
      end

      def suppress_messages?
        handler_name =~ /cgi/i || quiet
      end

      def setup_traps
        return unless traps?

        at_exit { quit! }

        %i[INT TERM].each do |signal|
          old_handler = trap(signal) do
            quit!
            old_handler.call if old_handler.respond_to?(:call)
          end
        end

        set :traps, false
      end

      # Dynamically defines a method on settings.
      def define_singleton(name, content = Proc.new)
        singleton_class.class_eval do
          undef_method(name) if method_defined? name
          String === content ? class_eval("def #{name}() #{content}; end") : define_method(name, &content)
        end
      end

      # Condition for matching host name. Parameter might be String or Regexp.
      def host_name(pattern)
        condition { pattern === request.host }
      end

      # Condition for matching user agent. Parameter should be Regexp.
      # Will set params[:agent].
      def user_agent(pattern)
        condition do
          if request.user_agent.to_s =~ pattern
            @params[:agent] = $~[1..-1]
            true
          else
            false
          end
        end
      end
      alias agent user_agent

      # Condition for matching mimetypes. Accepts file extensions.
      def provides(*types)
        types.map! { |t| mime_types(t) }
        types.flatten!
        condition do
          response_content_type = response['content-type']
          preferred_type = request.preferred_type(types)

          if response_content_type
            types.include?(response_content_type) || types.include?(response_content_type[/^[^;]+/])
          elsif preferred_type
            params = (preferred_type.respond_to?(:params) ? preferred_type.params : {})
            content_type(preferred_type, params)
            true
          else
            false
          end
        end
      end

      def route(verb, path, options = {}, &block)
        enable :empty_path_info if path == '' && empty_path_info.nil?
        signature = compile!(verb, path, block, **options)
        (@routes[verb] ||= []) << signature
        invoke_hook(:route_added, verb, path, block)
        signature
      end

      def invoke_hook(name, *args)
        extensions.each { |e| e.send(name, *args) if e.respond_to?(name) }
      end

      def generate_method(method_name, &block)
        define_method(method_name, &block)
        method = instance_method method_name
        remove_method method_name
        method
      end

      def compile!(verb, path, block, **options)
        # Because of self.options.host
        host_name(options.delete(:host)) if options.key?(:host)
        # Pass Mustermann opts to compile()
        route_mustermann_opts = options.key?(:mustermann_opts) ? options.delete(:mustermann_opts) : {}.freeze

        options.each_pair { |option, args| send(option, *args) }

        pattern                 = compile(path, route_mustermann_opts)
        method_name             = "#{verb} #{path}"
        unbound_method          = generate_method(method_name, &block)
        conditions = @conditions
        @conditions = []
        wrapper = block.arity.zero? ?
          proc { |a, _p| unbound_method.bind(a).call } :
          proc { |a, p| unbound_method.bind(a).call(*p) }

        [pattern, conditions, wrapper]
      end

      def compile(path, route_mustermann_opts = {})
        Mustermann.new(path, **mustermann_opts.merge(route_mustermann_opts))
      end

      def setup_default_middleware(builder)
        # ExtendedRack is no longer installed by default: the EventMachine/Thin
        # async.callback path it supported is gone (Rack 3 streaming bodies
        # replace it). It survives only as an inert, deprecation-warning shim for
        # apps that still `use Sinatra::ExtendedRack` explicitly; see the class.
        builder.use ShowExceptions       if show_exceptions?
        builder.use Rack::MethodOverride if method_override?
        builder.use Rack::Head
        setup_logging    builder
        setup_sessions   builder
        setup_protection builder
        setup_host_authorization builder
      end

      def setup_middleware(builder)
        middleware.each { |c, a, b| builder.use(c, *a, &b) }
      end

      def setup_logging(builder)
        if logging?
          setup_common_logger(builder)
          setup_custom_logger(builder)
        elsif logging == false
          setup_null_logger(builder)
        end
      end

      def setup_null_logger(builder)
        builder.use Sinatra::Middleware::Logger, ::Logger::FATAL
      end

      def setup_common_logger(builder)
        builder.use Sinatra::CommonLogger
      end

      def setup_custom_logger(builder)
        if logging.respond_to? :to_int
          builder.use Sinatra::Middleware::Logger, logging
        else
          builder.use Sinatra::Middleware::Logger
        end
      end

      def setup_protection(builder)
        return unless protection?

        options = Hash === protection ? protection.dup : {}
        options = {
          img_src: "'self' data:",
          font_src: "'self'"
        }.merge options

        protect_session = options.fetch(:session) { sessions? }
        options[:without_session] = !protect_session

        options[:reaction] ||= :drop_session

        builder.use Rack::Protection, options
      end

      def setup_host_authorization(builder)
        builder.use Rack::Protection::HostAuthorization, host_authorization
      end

      def setup_sessions(builder)
        return unless sessions?

        options = {}
        options[:secret] = session_secret if session_secret?
        options.merge! sessions.to_hash if sessions.respond_to? :to_hash
        builder.use session_store, options
      end

      def inherited(subclass)
        subclass.reset!
        subclass.set :app_file, caller_files.first unless subclass.app_file?
        super
      end

      @@mutex = Mutex.new
      def synchronize(&block)
        if lock?
          @@mutex.synchronize(&block)
        else
          yield
        end
      end

      # used for deprecation warnings
      def warn_for_deprecation(message)
        warn message + "\n\tfrom #{cleaned_caller.first.join(':')}"
      end

      # Like Kernel#caller but excluding certain magic entries
      def cleaned_caller(keep = 3)
        caller(1)
          .map! { |line| line.split(/:(?=\d|in )/, 3)[0, keep] }
          .reject { |file, *_| callers_to_ignore.any? { |pattern| file =~ pattern } }
      end
    end

    # Force data to specified encoding. It defaults to settings.default_encoding
    # which is UTF-8 by default
    def self.force_encoding(data, encoding = default_encoding)
      return if data == settings || data.is_a?(Tempfile)

      if data.respond_to? :force_encoding
        data.force_encoding(encoding).encode!
      elsif data.respond_to? :each_value
        data.each_value { |v| force_encoding(v, encoding) }
      elsif data.respond_to? :each
        data.each { |v| force_encoding(v, encoding) }
      end
      data
    end

    def force_encoding(*args)
      settings.force_encoding(*args)
    end

    reset!

    set :environment, (ENV['APP_ENV'] || ENV['RACK_ENV'] || :development).to_sym
    set :raise_errors, proc { test? }
    set :dump_errors, proc { !test? }
    set :show_exceptions, proc { development? }
    set :sessions, false
    set :session_store, Rack::Session::Cookie
    set :logging, false
    set :protection, true
    set :method_override, false
    set :use_code, false
    set :default_encoding, 'utf-8'
    set :x_cascade, true
    set :add_charset, %w[javascript xml xhtml+xml].map { |t| "application/#{t}" }
    settings.add_charset << %r{^text/}
    set :mustermann_opts, {}
    set :default_content_type, 'text/html'

    # Streaming concurrency cap (per process): the maximum number of parked
    # keep_open streams. Past it, the #stream helper sheds with 503 + the
    # stream_retry_after header instead of parking another worker thread/fiber.
    # Set to nil to disable the cap.
    set :stream_max_concurrent, 1000
    set :stream_retry_after, 5
    # Default keep_open ceiling in seconds: a parked stream self-closes after this
    # (plus jitter) so a leaked or idle connection cannot park forever. Override
    # per stream with stream(..., ttl:), or set to nil to disable the default.
    set :stream_keep_open_ttl, 300
    # Handlers invoked when a streaming producer block raises mid-stream, set
    # via on_stream_error. Each receives the exception; the exception still
    # propagates afterwards.
    set :stream_error_handlers, []

    # explicitly generating a session secret eagerly to play nice with preforking
    begin
      require 'securerandom'
      set :session_secret, SecureRandom.hex(64)
    rescue LoadError, NotImplementedError, RuntimeError
      # SecureRandom raises a NotImplementedError if no random device is available
      # RuntimeError raised due to broken openssl backend: https://bugs.ruby-lang.org/issues/19230
      set :session_secret, format('%064x', Kernel.rand((2**256) - 1))
    end

    class << self
      alias methodoverride? method_override?
      alias methodoverride= method_override=
    end

    set :run, false                       # start server via at-exit hook?
    set :running_server, nil
    set :handler_name, nil
    set :traps, true
    set :server, %w[webrick]
    set :bind, proc { development? ? 'localhost' : '0.0.0.0' }
    set :port, Integer(ENV['PORT'] && !ENV['PORT'].empty? ? ENV['PORT'] : 4567)
    set :quiet, false
    set :host_authorization, ->() do
      if development?
        {
          permitted_hosts: [
            "localhost",
            ".localhost",
            ".test",
            IPAddr.new("0.0.0.0/0"),
            IPAddr.new("::/0"),
          ]
        }
      else
        {}
      end
    end

    ruby_engine = defined?(RUBY_ENGINE) && RUBY_ENGINE

    server.unshift 'thin'     if ruby_engine != 'jruby'
    server.unshift 'falcon'   if ruby_engine != 'jruby'
    server.unshift 'trinidad' if ruby_engine == 'jruby'
    server.unshift 'puma'

    set :absolute_redirects, true
    set :prefixed_redirects, false
    set :empty_path_info, nil
    set :strict_paths, true

    set :app_file, nil
    set :root, proc { app_file && File.expand_path(File.dirname(app_file)) }
    set :views, proc { root && File.join(root, 'views') }
    set :reload_templates, proc { development? }
    set :lock, false
    set :threaded, true

    set :public_folder, proc { root && File.join(root, 'public') }
    set :static, proc { public_folder && File.exist?(public_folder) }
    set :static_cache_control, false

    set :static_headers, {}

    error ::Exception do
      response.status = 500
      content_type 'text/html'
      '<h1>Internal Server Error</h1>'
    end

    configure :development do
      get '/__sinatra__/:image.png' do
        filename = __dir__ + "/images/#{params[:image].to_i}.png"
        content_type :png
        send_file filename
      end

      error NotFound do
        content_type 'text/html'

        if instance_of?(Sinatra::Application)
          code = <<-RUBY.gsub(/^ {12}/, '')
            #{request.request_method.downcase} '#{request.path_info}' do
              "Hello World"
            end
          RUBY
        else
          code = <<-RUBY.gsub(/^ {12}/, '')
            class #{self.class}
              #{request.request_method.downcase} '#{request.path_info}' do
                "Hello World"
              end
            end
          RUBY

          file = settings.app_file.to_s.sub(settings.root.to_s, '').sub(%r{^/}, '')
          code = "# in #{file}\n#{code}" unless file.empty?
        end

        <<-HTML.gsub(/^ {10}/, '')
          <!DOCTYPE html>
          <html>
          <head>
            <style type="text/css">
            body { text-align:center;font-family:helvetica,arial;font-size:22px;
              color:#888;margin:20px}
            #c {margin:0 auto;width:500px;text-align:left}
            </style>
          </head>
          <body>
            <h2>Sinatra doesn’t know this ditty.</h2>
            <img src='#{request.script_name}/__sinatra__/404.png'>
            <div id="c">
              Try this:
              <pre>#{Rack::Utils.escape_html(code)}</pre>
            </div>
          </body>
          </html>
        HTML
      end
    end
  end

  # Execution context for classic style (top-level) applications. All
  # DSL methods executed on main are delegated to this class.
  #
  # The Application class should not be subclassed, unless you want to
  # inherit all settings, routes, handlers, and error pages from the
  # top-level. Subclassing Sinatra::Base is highly recommended for
  # modular applications.
  class Application < Base
    set :logging, proc { !test? }
    set :method_override, true
    set :run, proc { !test? }
    set :app_file, nil

    def self.register(*extensions, &block) # :nodoc:
      added_methods = extensions.flat_map(&:public_instance_methods)
      Delegator.delegate(*added_methods)
      super(*extensions, &block)
    end
  end

  # Sinatra delegation mixin. Mixing this module into an object causes all
  # methods to be delegated to the Sinatra::Application class. Used primarily
  # at the top-level.
  module Delegator # :nodoc:
    def self.delegate(*methods)
      methods.each do |method_name|
        next if method_defined?(method_name) || private_method_defined?(method_name)

        define_method(method_name) do |*args, &block|
          return super(*args, &block) if respond_to? method_name

          Delegator.target.send(method_name, *args, &block)
        end
        # ensure keyword argument passing is compatible with ruby >= 2.7
        ruby2_keywords(method_name) if respond_to?(:ruby2_keywords, true)
        private method_name
      end
    end

    delegate :get, :patch, :put, :post, :delete, :head, :options, :link, :unlink,
             :template, :layout, :before, :after, :error, :not_found, :configure,
             :set, :mime_type, :enable, :disable, :use, :development?, :test?,
             :production?, :helpers, :settings, :register, :on_start, :on_stop

    class << self
      attr_accessor :target
    end

    self.target = Application
  end

  class Wrapper
    def initialize(stack, instance)
      @stack = stack
      @instance = instance
    end

    def settings
      @instance.settings
    end

    def helpers
      @instance
    end

    def call(env)
      @stack.call(env)
    end

    def inspect
      "#<#{@instance.class} app_file=#{settings.app_file.inspect}>"
    end
  end

  # Create a new Sinatra application; the block is evaluated in the class scope.
  def self.new(base = Base, &block)
    base = Class.new(base)
    base.class_eval(&block) if block_given?
    base
  end

  # Extend the top-level DSL with the modules provided.
  def self.register(*extensions, &block)
    Delegator.target.register(*extensions, &block)
  end

  # Include the helper modules provided in Sinatra's request context.
  def self.helpers(*extensions, &block)
    Delegator.target.helpers(*extensions, &block)
  end

  # Use the middleware for classic applications.
  def self.use(*args, &block)
    Delegator.target.use(*args, &block)
  end
end
