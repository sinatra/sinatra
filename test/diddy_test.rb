require File.dirname(__FILE__) + '/helper'

context "Diddy" do

  setup do
    Sinatra.application = nil
  end

  specify "should map urls to different apps" do

    get '/' do
      'asdf'
    end
    
    get_it '/'
    assert ok?
    assert_equal('asdf', body)
    
    get '/foo', :host => 'foo.sinatrarb.com' do
      'in foo!'
    end

    get '/foo', :host => 'bar.sinatrarb.com'  do
      'in bar!'
    end
    
    get_it '/foo', {}, 'HTTP_HOST' => 'foo.sinatrarb.com'
    assert ok?
    assert_equal 'in foo!', body

    get_it '/foo', {}, 'HTTP_HOST' => 'bar.sinatrarb.com'
    assert ok?
    assert_equal 'in bar!', body
    
    get_it '/foo'
    assert not_found?
    
  end

end

