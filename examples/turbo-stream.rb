#!/usr/bin/env ruby -I ../lib -I lib
# frozen_string_literal: true
require 'sinatra'

# Minimal example of using turbo-streams to update the frontend page,
# based on server-side broadcasts.
#
# Explanations:
# <turbo-stream-source src="/next"> => specify the address of the event-stream
#
# When the page loads, the browser opens the event-stream.
# The matching handler on the Sinatra side saves the connection in a set
# called `conns` and a background thread sends an event every second
# to all the connections in the `conns` set.
#
# The target of the event (`subscriber-list`) must match the HTML
# element already present in the page.

conns = Set.new

set :server, :puma

get '/' do
<<END
<!DOCTYPE html>
<html lang="en">
<head>
  <script type="module" integrity="sha384-snAbo4VirmpRdbk7i0NI/mKq/BNeGFpjEal+XmSkiuqgpDd/UhIlGcxLcKeag0CF" src="https://cdn.jsdelivr.net/npm/@hotwired/turbo@8.0.13/dist/turbo.es2017-esm.min.js"></script>
  <meta charset="UTF-8">
</head>
<body>
  <turbo-stream-source src="/next"></turbo-stream-source>
  <h1>User list updated in real-time</h1>
  <ul id="subscriber-list">
    <li>user 1</li>
    <li>user 2</li>
  </ul>
</body>
</html>
END
end

# Background thread that acts as event-generator.
# Its task is to broadcast (to all online clients) a new user to append every second.
Thread.new {
  while true
    conns.each do |out|
      out <<
<<END
event: message
data: <turbo-stream action="append" target="subscriber-list"><template><li>patched user</li></template></turbo-stream>

END
    rescue
      # If the connection throws an error (such as interrupted connections or closed browser tabs), close that connection.
      out.close
    end
    sleep 1 
  end
}

get '/next', provides: 'text/event-stream' do
  stream :keep_open do |out|
    if conns.add?(out)
      print "Added connection\n"
      out.callback { conns.delete(out) }
    end
    sleep 1
  rescue
    out.close
  end
end
