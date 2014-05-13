require 'spec_helper'

describe Sinatra::MultiRoute do

  it 'does not break normal routing' do
    mock_app do
      register Sinatra::MultiRoute
      get('/') { 'normal' }
    end

    get('/').should be_ok
    body.should be == 'normal'
  end

  it 'supports multiple routes' do
    mock_app do
      register Sinatra::MultiRoute
      get('/foo', '/bar') { 'paths' }
    end

    get('/foo').should be_ok
    body.should be == 'paths'
    get('/bar').should be_ok
    body.should be == 'paths'
  end

  it 'triggers conditions' do
    count = 0
    mock_app do
      register Sinatra::MultiRoute
      set(:some_condition) { |_| count += 1 }
      get('/foo', '/bar', :some_condition => true) { 'paths' }
    end

    count.should be == 4
  end

  it 'supports multiple verbs' do
    mock_app do
      register Sinatra::MultiRoute
      route('PUT', 'POST', '/') { 'verb' }
    end

    post('/').should be_ok
    body.should be == 'verb'
    put('/').should be_ok
    body.should be == 'verb'
  end

  it 'takes symbols as verbs' do
    mock_app do
      register Sinatra::MultiRoute
      route(:get, '/baz') { 'symbol as verb' }
    end

    get('/baz').should be_ok
    body.should be == 'symbol as verb'
  end
end
