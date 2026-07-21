#!/usr/bin/env ruby -I ../lib -I lib
# frozen_string_literal: true

# This example does *not* work properly with WEBrick or other
# servers that buffer output. To shut down the server, close any
# open browser tabs that are connected to the chat server.

require 'sinatra'
set :server, :puma
connections = Set.new

get '/' do
  halt erb(:login) unless params[:user]
  erb :chat, locals: { user: params[:user].gsub(/\W/, '') }
end

get '/stream', provides: 'text/event-stream' do
  stream :keep_open do |out|
    connections << out
    # Drop this connection on disconnect, completion, or the keep_open TTL
    # expiring. A failed write is now treated as a clean teardown, so there is
    # no manual rescue here.
    out.callback { connections.delete(out) }
    out.sse_comment 'connected'
  end
end

post '/' do
  # Dup so the teardown callbacks (which delete from the set) do not mutate it
  # mid-iteration. Writing to a vanished client is reaped for us.
  connections.dup.each { |out| out.sse(params[:msg]) }
  204 # response without entity body
end

__END__

@@ layout
<html>
  <head>
    <title>Super Simple Chat with Sinatra</title>
    <meta charset="utf-8" />
    <script src="http://ajax.googleapis.com/ajax/libs/jquery/1/jquery.min.js"></script>
  </head>
  <body><%= yield %></body>
</html>

@@ login
<form action="/">
  <label for='user'>User Name:</label>
  <input name="user" value="" />
  <input type="submit" value="GO!" />
</form>

@@ chat
<pre id='chat'></pre>
<form>
  <input id='msg' placeholder='type message here...' />
</form>

<script>
  // reading
  var es = new EventSource('/stream');
  es.onmessage = function(e) { $('#chat').append(e.data + "\n") };

  // writing
  $("form").on('submit',function(e) {
    $.post('/', {msg: "<%= user %>: " + $('#msg').val()});
    $('#msg').val(''); $('#msg').focus();
    e.preventDefault();
  });
</script>

