$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'
require 'sinatra'

get '/' do
  @items = session[:items] || []
  haml <<-haml
%script window.document.getElementById('new_item').focus();
%h1 Sinatra's todo list
%ul
  - @items.each_with_index do |item, index|
    %li.item
      %div
        = item
        %form{:action => "/" + index.to_s, :method => 'POST'}
          %input{:type => 'hidden', :name => '_method', :value => 'DELETE'}
          %input{:type => 'submit', :value => 'delete'}
%form{:action => '/clear', :method => 'POST'}
  %input{:value => 'clear', :type => :submit}
%form{:action => '/', :method => 'POST'}
  %input{:type => 'textbox', :name => :new_item, :id => 'new_item'}
  %input{:type => 'submit'}
  haml
end

post '/' do
  (session[:items] ||= []) << params[:new_item] unless params[:new_item].to_s.strip.empty?
  redirect '/'
end

post '/clear' do
  session[:items].clear
  redirect '/'
end

delete '/:id' do
  session[:items].delete_at(params[:id].to_i)
  redirect '/'
end
