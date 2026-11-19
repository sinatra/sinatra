#!/usr/bin/env ruby -I ../lib -I lib
# frozen_string_literal: true

# Server-Sent Events with the streaming helpers. This does *not* work under
# WEBrick or other buffering servers. Run under a streaming-capable server:
#
#   puma examples/sse.rb              # gem install puma
#   falcon serve -b http://localhost:9292 -c examples/sse.rb   # gem install falcon
#
# Then open http://localhost:9292 in a browser, or watch the raw stream with:
#
#   curl -N http://localhost:9292/events

require 'sinatra/base'

class SSEExample < Sinatra::Base
  # A producer error happens after the response headers are sent, so the status
  # cannot change and it never reaches an `error` block. Register a hook to
  # report it (in a real app: Sentry, OpenTelemetry, your logger).
  on_stream_error { |e| warn "sse stream error: #{e.class}: #{e.message}" }

  get '/events', provides: 'text/event-stream' do
    content_type 'text/event-stream'
    # On reconnect the browser sends the id of the last event it received, so we
    # can resume after it instead of starting over.
    last_seen = request.env['HTTP_LAST_EVENT_ID'].to_i

    stream(:keep_open) do |out|
      n = last_seen
      loop do
        n += 1
        out.sse({ count: n, at: Time.now.to_i }, event: 'tick', id: n)
        out.flush # push each event immediately rather than waiting for a buffer
        sleep 1
      end
    end
    # When the client disconnects, the next write raises and the stream is torn
    # down for us; the loop does not need its own disconnect handling.
  end

  get '/' do
    <<~HTML
      <!doctype html><meta charset="utf-8"><title>Sinatra SSE example</title>
      <pre id="log"></pre>
      <script>
        const es = new EventSource('/events');
        es.addEventListener('tick', (e) => {
          document.getElementById('log').textContent += e.lastEventId + ': ' + e.data + "\\n";
        });
      </script>
    HTML
  end
end

SSEExample.run! if $PROGRAM_NAME == __FILE__
