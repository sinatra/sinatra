require_relative 'test_helper'
require 'socket'
require 'timeout'

class StreamingTest < Minitest::Test
  Stream = Sinatra::Helpers::Stream

  # The process-wide active-stream gauge is shared mutable state; reset it before
  # each test so a stream left parked by one test cannot skew another's cap math.
  def setup
    super
    Stream.instance_variable_set(:@active, 0)
  end

  # A double for the Rack 3 server-provided stream. Implements the full
  # interface Rack::Lint's StreamWrapper requires (read, write, <<, flush,
  # close, close_read, close_write, closed?) so the same object can be used
  # both as a hand-driven test double and validated against the real protocol.
  class FakeStream
    attr_reader :chunks

    def initialize(write_error: nil, fail_after: nil)
      @chunks      = []
      @closed      = false
      @write_error = write_error
      @fail_after  = fail_after # raise @write_error only from the Nth write on
    end

    def write(data)
      if @write_error && (@fail_after.nil? || @chunks.length >= @fail_after)
        raise @write_error
      end

      @chunks << data
      data.bytesize
    end

    def <<(data)
      write(data)
      self
    end

    def read(*)  nil  end
    def flush;   self end

    def close
      @closed = true
    end

    def close_read;  end
    def close_write; end

    def closed?
      @closed
    end

    def body
      @chunks.join
    end
  end

  # Drives a Stream callable body the way a Rack 3 server would.
  def drive(stream, fake = FakeStream.new)
    stream.call(fake)
    fake
  end

  it 'returns the concatenated body' do
    skip_unless_rack_buffers_callable_body
    mock_app do
      get('/') do
        stream do |out|
          out << 'Hello' << ' '
          out << 'World!'
        end
      end
    end

    get('/')
    assert_body 'Hello World!'
  end

  it 'always yields strings' do
    stream = Stream.new { |out| out << :foo }
    fake = drive(stream)
    assert_equal ['foo'], fake.chunks
  end

  it 'postpones body generation' do
    step = 0

    stream = Stream.new do |out|
      10.times do
        out << step
        step += 1
      end
    end

    # Nothing runs until the server calls #call.
    assert_equal 0, step
    fake = drive(stream)
    assert_equal 10, step
    assert_equal (0...10).map(&:to_s), fake.chunks
  end

  it 'calls the callback after it is done' do
    step   = 0
    final  = 0
    stream = Stream.new { |_| 10.times { step += 1 } }
    stream.callback { final = step }
    drive(stream)
    assert_equal 10, final
  end

  it 'does not trigger the callback if close is set to :keep_open' do
    step   = 0
    final  = 0
    stream = Stream.new(:keep_open) { |_| 10.times { step += 1 } }
    stream.callback { final = step }
    # keep_open holds #call open until close; close it from another thread so
    # #call returns and the test does not block forever.
    Thread.new { sleep 0.05; stream.close }
    drive(stream)
    # The callback fires only via the explicit close, which sets final = step.
    assert_equal 10, final
  end

  it 'does not auto-close a keep_open stream when the block returns' do
    closed = false
    stream = Stream.new(:keep_open) { |_| :done }
    stream.callback { closed = true }
    Thread.new { sleep 0.05; stream.close }
    drive(stream)
    # block returned but stream stayed open until the explicit close
    assert closed
  end

  it 'allows adding more than one callback' do
    a = b = false
    stream = Stream.new {}
    stream.callback { a = true }
    stream.callback { b = true }
    drive(stream)
    assert a, 'should trigger first callback'
    assert b, 'should trigger second callback'
  end

  it 'does not trigger an infinite loop if you call close in a callback' do
    stream = Stream.new { |out| out.callback { out.close } }
    drive(stream)
    assert stream.closed?
  end

  it 'gives access to route specific params' do
    skip_unless_rack_buffers_callable_body
    mock_app do
      get('/:name') do
        stream { |o| o << params[:name] }
      end
    end
    get '/foo'
    assert_body 'foo'
  end

  it 'fires callbacks on out.close' do
    ran = false
    stream = Stream.new(:keep_open) do |out|
      out.callback { ran = true }
      out.close
    end
    drive(stream)
    assert ran
  end

  it 'has a public interface to inspect its open/closed state' do
    stream = Stream.new { |out| out << :foo }
    assert !stream.closed?
    stream.close
    assert stream.closed?
  end

  # --- Rack 3 callable-body conformance ----------------------------------

  it 'is a callable body, not an enumerable body' do
    stream = Stream.new {}
    assert stream.respond_to?(:call), 'must respond to #call'
    assert !stream.respond_to?(:each), 'must NOT respond to #each'
  end

  it 'invokes the producer block exactly once' do
    count  = 0
    stream = Stream.new { |_| count += 1 }
    drive(stream)
    assert_equal 1, count
  end

  it 'closes the server stream when done' do
    fake   = FakeStream.new
    stream = Stream.new { |out| out << 'hi' }
    stream.call(fake)
    assert fake.closed?, 'server stream should be closed after #call'
  end

  it 'is idempotent on close' do
    calls  = 0
    stream = Stream.new {}
    stream.callback { calls += 1 }
    drive(stream)
    stream.close # Rack::Lint calls body.close after #call
    stream.close
    assert_equal 1, calls, 'callbacks must fire exactly once across repeated close'
  end

  it 'sets no content-length on the streamed response' do
    skip_unless_rack_buffers_callable_body
    mock_app do
      get('/') { stream { |o| o << 'data' } }
    end
    get '/'
    assert_nil headers['content-length']
    assert_body 'data'
  end

  it 'emits a bare arity-1 callable returned from a route as a streaming body' do
    skip_unless_rack_buffers_callable_body
    # U2: returning a Rack 3 streaming body directly (not via the stream helper)
    # used to fall through invoke and be dropped to an empty 200.
    mock_app do
      get('/') { ->(out) { out << 'u2'; out.close } }
    end
    get '/'
    assert_body 'u2'
    assert_nil headers['content-length']
  end

  it 'conforms to Rack::Lint as a streaming body' do
    require 'rack/lint'
    app = lambda do |_env|
      body = Stream.new { |out| out << 'a' << 'b' }
      [200, { 'content-type' => 'text/plain' }, body]
    end
    linted = Rack::Lint.new(app)
    env = Rack::MockRequest.env_for('/')
    status, _headers, body = linted.call(env)
    assert_equal 200, status
    assert body.respond_to?(:call)
    fake = FakeStream.new
    body.call(fake)
    body.close
    assert_equal 'ab', fake.body
  end

  # --- disconnect handling ----------------------------------------------

  it 'treats a client disconnect (ECONNRESET) as a clean teardown' do
    ran    = false
    fake   = FakeStream.new(write_error: Errno::ECONNRESET.new('reset'))
    stream = Stream.new { |out| out << 'never arrives' }
    stream.callback { ran = true }
    # #call must return cleanly, not raise.
    stream.call(fake)
    assert stream.closed?, 'stream should be closed after disconnect'
    assert ran, 'callbacks should still fire on disconnect'
  end

  it 'treats every socket disconnect errno as a clean teardown' do
    [Errno::EPIPE, Errno::ECONNRESET, Errno::ECONNABORTED,
     Errno::ESHUTDOWN, Errno::ENOTCONN].each do |errno|
      ran    = false
      fake   = FakeStream.new(write_error: errno.new('gone'))
      stream = Stream.new { |out| out << 'never arrives' }
      stream.callback { ran = true }
      stream.call(fake) # must not raise
      assert stream.closed?, "#{errno} should close the stream"
      assert ran, "#{errno} callbacks should still fire"
    end
  end

  # The narrowed predicate is the whole point of the fix: an app-level error
  # raised inside the producer block must NOT be mistaken for a disconnect and
  # silently swallowed into a truncated 200. It must reach the caller loud.
  it 'propagates a genuine application IOError (not a socket disconnect)' do
    fake   = FakeStream.new(write_error: IOError.new('closed stream'))
    stream = Stream.new { |out| out << 'x' }
    assert_raises(IOError) { stream.call(fake) }
    assert stream.closed?, 'stream must still be torn down before re-raising'
  end

  it 'propagates an app Errno::ENOENT (missing file) instead of swallowing it' do
    fake   = FakeStream.new
    stream = Stream.new { |_out| raise Errno::ENOENT, 'no such file' }
    assert_raises(Errno::ENOENT) { stream.call(fake) }
  end

  it 'propagates an app Errno::EACCES (permissions) instead of swallowing it' do
    fake   = FakeStream.new
    stream = Stream.new { |_out| raise Errno::EACCES, 'denied' }
    assert_raises(Errno::EACCES) { stream.call(fake) }
  end

  it 'propagates a genuine application error' do
    fake   = FakeStream.new
    stream = Stream.new { |_out| raise 'boom' }
    assert_raises(RuntimeError) { stream.call(fake) }
    assert fake.closed?, 'the server stream is still closed on an app error'
  end

  it 'still fires remaining callbacks if one raises a disconnect error' do
    second = false
    stream = Stream.new(:keep_open) {}
    stream.callback { raise Errno::EPIPE, 'broken pipe' }
    stream.callback { second = true }
    stream.close
    assert second, 'a disconnect-raising callback must not stop later callbacks'
  end

  # --- keep_open disconnect reaping -------------------------------------

  # A parked keep_open #call must wake and tear down when an out-of-band #close
  # arrives (server close, cross-request close, reaper EOF, h2 RST_STREAM all
  # funnel through #close -> broadcast). Without the broadcast this leaks the
  # worker thread forever.
  it 'reaps a parked keep_open stream when closed out of band' do
    reaped = false
    stream = Stream.new(:keep_open) { |_out| }
    stream.callback { reaped = true }
    closer = Thread.new { sleep 0.05; stream.close }
    drive(stream) # blocks in park until the broadcast wakes it
    closer.join
    assert stream.closed?
    assert reaped, 'parked keep_open #call must wake and fire callbacks on close'
  end

  # The heartbeat-probe path (Falcon shape: no raw socket). park writes the
  # heartbeat; when the peer is gone the write raises a disconnect errno, which
  # we surface as ClientDisconnected -> clean close, firing callbacks. This is
  # the leak fix: a silently-vanished client is detected by the periodic probe.
  it 'reaps a parked keep_open stream via the heartbeat probe on disconnect' do
    reaped = false
    # block writes once (succeeds), then the heartbeat write (2nd write) fails.
    fake   = FakeStream.new(write_error: Errno::EPIPE.new('broken pipe'),
                            fail_after: 1)
    stream = Stream.new(:keep_open, heartbeat: ":ping\n\n", poll: 0.02) do |out|
      out << 'open'
    end
    stream.callback { reaped = true }
    stream.call(fake) # parks, probes via heartbeat write, detects EPIPE, closes
    assert stream.closed?
    assert reaped, 'heartbeat probe must reap a silently-disconnected client'
  end

  # Falcon surfaces a closed output as a plain IOError (message "...closed..."),
  # not an errno. The heartbeat probe matches that ONE message on the write path
  # only and reaps; an unrelated IOError on the same probe must still raise.
  it 'reaps via the heartbeat probe on a Falcon-style closed IOError' do
    reaped = false
    fake   = FakeStream.new(write_error: IOError.new('Output stream closed'),
                            fail_after: 1)
    stream = Stream.new(:keep_open, heartbeat: ":ping\n\n", poll: 0.02) do |out|
      out << 'open'
    end
    stream.callback { reaped = true }
    stream.call(fake)
    assert stream.closed?
    assert reaped, 'closed-output IOError on the heartbeat probe must reap'
  end

  # The Puma shape: the server hijacks to a raw BasicSocket. park uses MSG_PEEK
  # (zero bytes on the wire) to detect EOF. We drive it with a real socketpair:
  # close the peer's write half, and the parked #call must reap on the next poll.
  it 'reaps a parked keep_open stream via MSG_PEEK EOF on a raw socket' do
    require 'socket'
    server, client = UNIXSocket.pair
    reaped = false
    stream = Stream.new(:keep_open, poll: 0.02) { |_out| }
    stream.callback { reaped = true }
    # peer (client) closes its write half -> server-side recv peeks EOF ("")
    client.close
    Timeout.timeout(2) { stream.call(server) }
    assert stream.closed?
    assert reaped, 'MSG_PEEK EOF must reap a disconnected raw-socket client'
  ensure
    server&.close rescue nil
    client&.close rescue nil
  end

  # A still-connected raw socket with no pending data must NOT be mistaken for a
  # disconnect: MSG_PEEK returns no readiness, park keeps waiting. We prove it
  # stays open, then close it explicitly to release the parked #call.
  it 'does not reap a live raw socket with no pending data' do
    require 'socket'
    server, client = UNIXSocket.pair
    stream = Stream.new(:keep_open, poll: 0.02) { |_out| }
    Thread.new do
      sleep 0.15 # several poll cycles; if it falsely reaped, closed? is true
      stream.close
    end
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Timeout.timeout(2) { stream.call(server) }
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
    assert stream.closed?
    assert elapsed >= 0.1, 'a live socket must keep the stream parked, not reap early'
  ensure
    server&.close rescue nil
    client&.close rescue nil
  end

  # --- public #stream helper: auto-heartbeat for SSE ---------------------

  # Drive the app to the Rack triple WITHOUT consuming the streaming body
  # (a Rack 3 callable body is only run when the server calls body.call). This
  # lets us grab the exact Stream object the PUBLIC #stream helper built and
  # drive it ourselves with a Falcon-shape FakeStream.
  def stream_body_for(path)
    env = Rack::MockRequest.env_for(path)
    _status, _headers, body = @app.call(env)
    body
  end

  # THE central iter-1 gap: a bare `stream(:keep_open)` SSE endpoint must
  # self-reap on a Falcon-shape disconnect THROUGH THE PUBLIC HELPER, i.e. the
  # helper must auto-enable the heartbeat for text/event-stream so the parked
  # #call probes by writing and detects the dead peer. No raw socket here
  # (FakeStream is not a BasicSocket), so the ONLY reaping signal is the
  # heartbeat the helper wires up by default for SSE.
  it 'auto-reaps a bare stream(:keep_open) SSE endpoint on Falcon-shape disconnect' do
    mock_app do
      get('/sse') do
        content_type 'text/event-stream'
        # No heartbeat: passed; it must be auto-enabled BECAUSE this is SSE.
        # poll: is short only so the test does not wait the 15s default.
        stream(:keep_open, poll: 0.02) { |out| out << "data: hi\n\n" }
      end
    end

    body = stream_body_for('/sse')
    # 1st write (the block) succeeds; the auto-heartbeat write (2nd) fails as if
    # the client vanished. With no auto-heartbeat this would park forever.
    fake = FakeStream.new(write_error: Errno::EPIPE.new('broken pipe'),
                          fail_after: 1)
    Timeout.timeout(2) { body.call(fake) }
    assert body.closed?, 'a bare stream(:keep_open) SSE endpoint must self-reap on Falcon'
  end

  # Companion proof that the auto-enabled SSE heartbeat is the invisible comment
  # (": \n"), not arbitrary bytes: capture what the probe writes to the wire.
  it 'auto-enables an invisible SSE comment heartbeat for a stream(:keep_open) SSE endpoint' do
    mock_app do
      get('/sse') do
        content_type 'text/event-stream'
        stream(:keep_open, poll: 0.02) { |out| out << "data: hi\n\n" }
      end
    end

    body = stream_body_for('/sse')
    fake = FakeStream.new
    closer = Thread.new { sleep 0.1; body.close } # let a few heartbeats land
    Timeout.timeout(2) { body.call(fake) }
    closer.join
    heartbeats = fake.chunks - ["data: hi\n\n"]
    refute_empty heartbeats, 'an SSE keep_open stream must emit a heartbeat probe'
    assert(heartbeats.all? { |c| c == ": \n" },
           "heartbeat must be the invisible SSE comment, got #{heartbeats.uniq.inspect}")
  end

  # The safety constraint: a NON-SSE keep_open stream must NOT get an
  # auto-heartbeat (it would inject garbage bytes into an arbitrary binary /
  # long-poll body). poll: is short so that IF a heartbeat were wrongly enabled,
  # many probe cycles would fire during the wait and corrupt fake.chunks, so the
  # assertion would then catch it. We close it out of band to release the park.
  it 'does NOT auto-inject heartbeat bytes into a non-SSE stream(:keep_open)' do
    mock_app do
      get('/binary') do
        content_type 'application/octet-stream'
        stream(:keep_open, poll: 0.01) { |out| out << 'PAYLOAD' }
      end
    end

    body = stream_body_for('/binary')
    fake = FakeStream.new
    closer = Thread.new { sleep 0.1; body.close } # ~10 poll cycles
    Timeout.timeout(2) { body.call(fake) }
    closer.join
    assert_equal ['PAYLOAD'], fake.chunks,
                 'a non-SSE keep_open stream must not have probe bytes injected'
  end

  # The content-type gate is start_with?, not include?: a spoofed content type
  # that merely CONTAINS 'text/event-stream' (e.g. 'x-text/event-stream-fake')
  # must NOT auto-enable the heartbeat, or an attacker could trick Sinatra into
  # injecting probe bytes into an arbitrary body. Same shape as the non-SSE case:
  # if a heartbeat were wrongly enabled, probe bytes would pollute fake.chunks.
  it 'does NOT auto-enable the heartbeat for a content type that only contains text/event-stream' do
    mock_app do
      get('/spoof') do
        content_type 'x-text/event-stream-fake'
        stream(:keep_open, poll: 0.01) { |out| out << 'PAYLOAD' }
      end
    end

    body = stream_body_for('/spoof')
    fake = FakeStream.new
    closer = Thread.new { sleep 0.1; body.close } # ~10 poll cycles
    Timeout.timeout(2) { body.call(fake) }
    closer.join
    assert_equal ['PAYLOAD'], fake.chunks,
                 'a spoofed event-stream content type must not get a heartbeat'
  end

  # The gate must still accept a real SSE content type carrying parameters
  # (charset), since start_with? matches the media type prefix before the ';'.
  it 'auto-enables the heartbeat for text/event-stream with a charset parameter' do
    mock_app do
      get('/sse') do
        content_type 'text/event-stream; charset=utf-8'
        stream(:keep_open, poll: 0.02) { |out| out << "data: hi\n\n" }
      end
    end

    body = stream_body_for('/sse')
    fake = FakeStream.new
    closer = Thread.new { sleep 0.1; body.close }
    Timeout.timeout(2) { body.call(fake) }
    closer.join
    heartbeats = fake.chunks - ["data: hi\n\n"]
    refute_empty heartbeats,
                 'text/event-stream; charset=utf-8 must still get a heartbeat'
  end

  # The escape hatch: a non-SSE keep_open user can still opt in to reaping by
  # passing heartbeat: explicitly through the public helper.
  it 'lets a non-SSE stream(:keep_open) opt in to a heartbeat for reaping' do
    mock_app do
      get('/binary') do
        content_type 'application/octet-stream'
        stream(:keep_open, heartbeat: "\0", poll: 0.02) { |out| out << 'PAYLOAD' }
      end
    end

    body = stream_body_for('/binary')
    fake = FakeStream.new(write_error: Errno::EPIPE.new('broken pipe'),
                          fail_after: 1)
    Timeout.timeout(2) { body.call(fake) }
    assert body.closed?, 'explicit heartbeat: must enable reaping on a non-SSE stream'
  end

  # --- empty stream ------------------------------------------------------

  it 'handles an empty stream cleanly' do
    fake   = FakeStream.new
    stream = Stream.new { |_out| }
    stream.call(fake)
    assert_empty fake.chunks
    assert stream.closed?
    assert fake.closed?
  end

  # --- finite default TTL self-close -------------------------------------

  # A keep_open stream that never sees a disconnect must still self-close once
  # the parking ceiling (ttl:) elapses, so an idle/leaked connection cannot park
  # forever. We give a tiny ttl and a live raw socket (so the MSG_PEEK probe
  # keeps reporting "still connected") and assert the TTL is what reaps it.
  it 'self-closes a parked keep_open stream when the TTL elapses' do
    require 'socket'
    server, client = UNIXSocket.pair
    reason = nil
    stream = Stream.new(:keep_open, poll: 0.02, ttl: 0.1) { |_out| }
    stream.callback { |r| reason = r }
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Timeout.timeout(2) { stream.call(server) }
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
    assert stream.closed?, 'a parked keep_open stream must self-close at its TTL'
    assert elapsed >= 0.1, 'must not reap before the TTL'
    assert elapsed < 1.5, 'must reap shortly after the TTL, not park forever'
    assert_equal :disconnect, reason, 'a TTL reap is a disconnect-class teardown'
  ensure
    server&.close rescue nil
    client&.close rescue nil
  end

  it 'parks indefinitely when ttl: nil opts out of the ceiling' do
    require 'socket'
    server, client = UNIXSocket.pair
    stream = Stream.new(:keep_open, poll: 0.02, ttl: nil) { |_out| }
    Thread.new { sleep 0.2; stream.close } # only an explicit close releases it
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Timeout.timeout(2) { stream.call(server) }
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
    assert stream.closed?
    assert elapsed >= 0.2, 'ttl: nil must disable the self-close ceiling'
  ensure
    server&.close rescue nil
    client&.close rescue nil
  end

  it 'defaults the parking ceiling to a finite generous value' do
    assert_equal 300, Stream::KEEP_OPEN_TTL,
                 'the default TTL must be finite so streams cannot park forever'
  end

  # --- concurrent-stream cap (503) ---------------------------------------

  # Past settings.stream_max_concurrent, the helper must shed with 503 +
  # Retry-After instead of parking another stream. We hold one slot open by
  # leaving a keep_open stream parked, set the cap to 1, then the next request
  # must 503. Driving through Rack::MockRequest gives us the real triple.
  it 'sheds a keep_open stream with 503 + Retry-After past the cap' do
    mock_app do
      set :stream_max_concurrent, 1
      set :stream_retry_after, 7
      get('/sse') do
        content_type 'text/event-stream'
        stream(:keep_open, poll: 0.02, ttl: nil) { |out| out << "data: hi\n\n" }
      end
    end

    # First request claims the only slot (we never drive its body, so it stays
    # claimed for the duration of the test).
    first = stream_body_for('/sse')
    assert_equal 1, Stream.active_count

    # Second request is over the cap -> 503 with Retry-After, no body parked.
    get('/sse')
    assert_status 503
    assert_equal '7', response['Retry-After']
    assert_match(/too many concurrent streams/i, response.body)
    assert_equal 1, Stream.active_count, 'a shed request must not consume a slot'
  ensure
    first&.close
  end

  it 'releases the slot when a parked keep_open stream closes' do
    mock_app do
      set :stream_max_concurrent, 1
      get('/sse') do
        content_type 'text/event-stream'
        stream(:keep_open, poll: 0.02, ttl: nil) { |out| out << "data: hi\n\n" }
      end
    end

    body = stream_body_for('/sse')
    assert_equal 1, Stream.active_count
    body.close
    assert_equal 0, Stream.active_count, 'closing a parked stream must free its slot'

    # The freed slot is reusable: another keep_open request now succeeds (200).
    again = stream_body_for('/sse')
    assert_equal 1, Stream.active_count
    again.close
  end

  it 'does not count a plain (non keep_open) stream against the cap' do
    skip_unless_rack_buffers_callable_body
    mock_app do
      set :stream_max_concurrent, 1
      get('/plain') do
        stream { |out| out << 'hello' }
      end
    end

    3.times do
      get('/plain')
      assert_status 200
      assert_body 'hello'
    end
    assert_equal 0, Stream.active_count
  end

  # --- producer-error hook -----------------------------------------------

  # A mid-stream application exception is invisible to the normal error channels,
  # so a registered on_stream_error handler must fire with the exception BEFORE
  # the error propagates. The error must still re-raise (loud failure preserved).
  it 'invokes on_stream_error with the exception and still propagates it' do
    captured = nil
    klass = Class.new(Sinatra::Base) do
      on_stream_error { |e| captured = e }
    end
    boom = RuntimeError.new('producer blew up')
    handlers = klass.settings.stream_error_handlers
    stream = Stream.new(error_handlers: handlers) { |_out| raise boom }
    fake = FakeStream.new

    err = assert_raises(RuntimeError) { stream.call(fake) }
    assert_same boom, err, 'the original exception must still propagate (loud)'
    assert_same boom, captured, 'on_stream_error must receive the exception'
    assert stream.closed?
  end

  it 'does not invoke on_stream_error on a clean disconnect' do
    called = false
    handlers = [->(_e) { called = true }]
    stream = Stream.new(:keep_open, poll: 0.02, error_handlers: handlers) do |out|
      out << 'data'
    end
    fake = FakeStream.new(write_error: Errno::EPIPE.new('broken pipe'),
                          fail_after: 1)
    Timeout.timeout(2) { stream.call(fake) }
    assert stream.closed?
    refute called, 'a peer disconnect is not an application error'
  end

  it 'isolates a raising error handler so the real exception still propagates' do
    boom = RuntimeError.new('real error')
    handlers = [->(_e) { raise 'reporter is broken' }, ->(_e) { @reached = true }]
    @reached = false
    stream = Stream.new(error_handlers: handlers) { |_out| raise boom }
    err = assert_raises(RuntimeError) { stream.call(FakeStream.new) }
    assert_same boom, err
    assert @reached, 'a broken handler must not block later handlers'
  end

  # --- reason-carrying teardown callback ---------------------------------

  it 'passes :complete to an arity-1 callback on a clean finish' do
    reason = nil
    stream = Stream.new { |out| out << 'done' }
    stream.callback { |r| reason = r }
    stream.call(FakeStream.new)
    assert_equal :complete, reason
  end

  it 'passes :disconnect to an arity-1 callback on a peer drop' do
    reason = nil
    stream = Stream.new { |out| out << 'x' }
    stream.callback { |r| reason = r }
    fake = FakeStream.new(write_error: Errno::EPIPE.new('broken pipe'))
    stream.call(fake)
    assert_equal :disconnect, reason
  end

  it 'passes :error to an arity-1 callback on an application exception' do
    reason = nil
    stream = Stream.new { |_out| raise 'boom' }
    stream.callback { |r| reason = r }
    assert_raises(RuntimeError) { stream.call(FakeStream.new) }
    assert_equal :error, reason
  end

  it 'still calls an arity-0 callback with no args (back-compatible)' do
    called = false
    stream = Stream.new { |out| out << 'done' }
    stream.callback { called = true } # zero-arity: must not get a reason arg
    stream.call(FakeStream.new)
    assert called
  end

  it 'fires a callback registered after close with :complete for arity 1' do
    stream = Stream.new { |out| out << 'done' }
    stream.call(FakeStream.new)
    assert stream.closed?
    reason = nil
    stream.callback { |r| reason = r } # registered post-close: fires immediately
    assert_equal :complete, reason
  end

  # --- HTTP/2 skip-heartbeat fast-path -----------------------------------

  # On HTTP/2+ the protocol reaps a closed stream natively, so the write-probe
  # heartbeat is dead weight and must NOT fire: no probe bytes on the wire, and
  # a disconnect is detected by the broadcast/poll backstop, not by a write.
  it 'skips the write-probe heartbeat on HTTP/2' do
    stream = Stream.new(:keep_open, heartbeat: ": \n", poll: 0.02,
                        protocol: 'HTTP/2') { |out| out << "data: hi\n\n" }
    fake = FakeStream.new
    closer = Thread.new { sleep 0.1; stream.close } # several poll cycles
    Timeout.timeout(2) { stream.call(fake) }
    closer.join
    assert_equal ["data: hi\n\n"], fake.chunks,
                 'HTTP/2 must not emit write-probe heartbeats (native reaping)'
  end

  it 'still emits the write-probe heartbeat on HTTP/1.1' do
    stream = Stream.new(:keep_open, heartbeat: ": \n", poll: 0.02,
                        protocol: 'HTTP/1.1') { |out| out << "data: hi\n\n" }
    fake = FakeStream.new
    closer = Thread.new { sleep 0.1; stream.close }
    Timeout.timeout(2) { stream.call(fake) }
    closer.join
    heartbeats = fake.chunks - ["data: hi\n\n"]
    refute_empty heartbeats, 'HTTP/1.1 must still write-probe for disconnect'
    assert(heartbeats.all? { |c| c == ": \n" })
  end

  # An actively-writing stream already exercises the transport on every event, so
  # the synthetic heartbeat must back off: a stream writing faster than the poll
  # interval should never accrue a single ": \n" probe. (The idle case is covered
  # by 'still emits the write-probe heartbeat on HTTP/1.1' above.)
  it 'suppresses the write-probe heartbeat while the stream is actively writing' do
    out_ref = nil
    stream  = Stream.new(:keep_open, heartbeat: ": \n", poll: 0.05,
                         protocol: 'HTTP/1.1') { |out| out_ref = out }
    fake    = FakeStream.new
    writer  = Thread.new do
      # Write every ~10ms, five times faster than the 50ms poll, so the parked
      # loop always sees a write within the last poll and skips the probe.
      50.times do
        sleep 0.01
        out_ref&.<<("data: tick\n\n")
      end
      stream.close
    end
    Timeout.timeout(3) { stream.call(fake) }
    writer.join
    assert_empty fake.chunks.select { |c| c == ": \n" },
                 'an actively-writing stream must not get injected heartbeat probes'
    refute_empty fake.chunks.select { |c| c == "data: tick\n\n" },
                 'the application writes themselves must still reach the wire'
  end

  it 'treats a nil/unknown protocol as HTTP/1 (heartbeat still fires)' do
    stream = Stream.new(:keep_open, heartbeat: ": \n", poll: 0.02,
                        protocol: nil) { |out| out << "data: hi\n\n" }
    fake = FakeStream.new
    closer = Thread.new { sleep 0.1; stream.close }
    Timeout.timeout(2) { stream.call(fake) }
    closer.join
    refute_empty(fake.chunks - ["data: hi\n\n"],
                 'nil protocol must default to the HTTP/1 write-probe')
  end

  it 'reaps an HTTP/2 disconnect via the broadcast backstop, not a write-probe' do
    # The server's native close (here: an explicit #close, standing in for
    # Falcon's closed(error) broadcast) wakes the parked fiber with no heartbeat.
    stream = Stream.new(:keep_open, heartbeat: ": \n", poll: 5,
                        protocol: 'HTTP/2') { |out| out << "data: hi\n\n" }
    fake = FakeStream.new
    reason = nil
    stream.callback { |r| reason = r }
    Thread.new { sleep 0.1; stream.close(:disconnect) }
    Timeout.timeout(2) { stream.call(fake) }
    assert stream.closed?
    assert_equal ["data: hi\n\n"], fake.chunks
    assert_equal :disconnect, reason
  end

  # --- Maintenance tripwires ---------------------------------------------

  it 'tripwire: KEEP_OPEN_TTL constant and the :stream_keep_open_ttl default stay in sync' do
    # The constant is the fallback for a direct Stream.new; the setting is the
    # configurable default the #stream helper uses. They must not drift apart.
    app = Class.new(Sinatra::Base)
    assert_equal Stream::KEEP_OPEN_TTL, app.settings.stream_keep_open_ttl
  end

  it 'tripwire: Rack::Deflater still cannot wrap a streaming body' do
    # Rack::Deflater is each-based and raises on a Rack 3 callable streaming
    # body. The README tells users not to compress streams because of this. If
    # Rack ever teaches Deflater about streaming bodies, consuming the wrapped
    # body stops raising here: update that README note and drop this tripwire.
    require 'rack/deflater'
    inner = lambda { |_env| [200, { 'content-type' => 'text/plain' }, Stream.new { |o| o << 'x' }] }
    _status, _headers, body = Rack::Deflater.new(inner)
                                            .call(Rack::MockRequest.env_for('/', 'HTTP_ACCEPT_ENCODING' => 'gzip'))
    assert_raises(NoMethodError) { body.each { |_chunk| } }
  end
end
