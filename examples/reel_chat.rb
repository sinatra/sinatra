# chat.rb
require 'sinatra/base'
# this also loads celluloid io, let's keep that in mind
require 'celluloid/current'
require 'reel'

# The chat server, an IO Event Loop held by the actor
# Collects connections (Reel Event Streams)
# 
# Contrary to EventMachine, there is no event callback for
# when the user disconnects, writes will just fail, we 
# therefore only remove these connections when writes fail.
#
class ChatServer
  include Celluloid::IO
  attr_reader :connections
  def initialize
    @connections = []
  end

  def listen(connection)
    @connections << connection
  end

  def broadcast(message)
    # TODO: improve this
    # consider that the connections has 10000 clients
    # we spend most of the team iterating and creating 10000 
    # celluloid tasks/fibers, starving resources while only do
    # stuff in the end. 
    # improvement: take it in batches of N connections, async/unicast
    # them, and then sleep, so that the allocated tasks can be run
    @connections.each do |connection|
      async(:unicast, connection, message)
    end
  end

  def unicast(connection, message)
    connection.write(message)
  rescue Reel::SocketError
    @connections.delete(connection)
  end

end

# Supervise all the things
config = Celluloid::Supervision::Configuration.new
config.define type: ChatServer, as: :chat_server
config.deploy

# Somehow Celluloid IO doesn't work well with sinatra classic applications, supervisor blows up. 
class Server < Sinatra::Base
  set server: 'puma',
      chat_server: Celluloid::Actor[:chat_server]
      
  get '/' do
    halt erb(:login) unless params[:user]
    erb :chat, locals: { user: params[:user].gsub(/\W/, '') }
  end
  

  # This is the secret sauce, we just reuse the reel
  # built-in Classes to act on this. From the puma perspective,
  # we hijack the socket and pass it to the reel connection, which 
  # will later pass it to our chat server above. Puma worker is free. 
  get '/stream', provides: 'text/event-stream' do
    io = env['rack.hijack'].call
    io = ::Celluloid::IO::TCPSocket.new(io)
    writer = Reel::Response::Writer.new(io)
  
  
    event_stream = ::Reel::EventStream.new do |event_stream|
      settings.chat_server.async(:listen, event_stream)
    end
    resp = Reel::StreamResponse.new(:ok,
           {
             'Content-Type' => 'text/event-stream; charset=utf-8',
             'Cache-Control' => 'no-cache',
             'X-Accel-Buffering' => 'no'
           },
           event_stream)
  
    writer.handle_response(resp)
    resp
  end
  
  post '/' do
    settings.chat_server.async(:broadcast, "data: #{params[:msg]}\n\n")
    204 # response without entity body
  end

  template :layout do
<<-HTML
<html>
  <head> 
    <title>Super Simple Chat with Sinatra</title> 
    <meta charset="utf-8" />
    <script src="http://ajax.googleapis.com/ajax/libs/jquery/1/jquery.min.js"></script> 
  </head> 
  <body><%= yield %></body>
</html>
HTML
  end
  template :login do
<<-HTML
<form action='/'>
  <label for='user'>User Name:</label>
  <input name='user' value='' />
  <input type='submit' value="GO!" />
</form>
HTML
  end
  
  template :chat do
<<-HTML
<pre id='chat'></pre>

<form>
  <input id='msg' placeholder='type message here...' />
</form>

<script>
  // reading
  var es = new EventSource('/stream');
  es.onmessage = function(e) { $('#chat').append(e.data + "\\n") };

  // writing
  $("form").on("submit", function(e) {
    $.post('/', {msg: "<%= user %>: " + $('#msg').val()});
    $('#msg').val(''); $('#msg').focus();
    e.preventDefault();
    return false;
  });
</script>
HTML
  end
end

# config.ru
require_relative "chat.rb"
run Server

# run this with rack and puma