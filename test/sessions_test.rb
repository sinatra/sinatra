require File.dirname(__FILE__) + '/helper'

context "Sessions" do
  
  specify "should be off by default" do
    Sinatra.application = nil

    get '/asdf' do
      session[:test] = true
      "asdf"
    end

    get '/test' do
      session[:test] == true ? "true" : "false"
    end
    
    get_it '/asdf', {}, 'HTTP_HOST' => 'foo.sinatrarb.com'
    assert ok?
    assert !include?('Set-Cookie')
  end
  
  specify "should be able to store data accross requests" do
    set_options(:sessions => true)
    Sinatra.application = nil

    get '/foo' do
      session[:test] = true
      "asdf"
    end

    get '/bar' do
      session[:test] == true ? "true" : "false"
    end

    get_it '/foo', :env => { :host => 'foo.sinatrarb.com' }
    assert ok?
    assert include?('Set-Cookie')    
  end
  
end
