require 'backports'
require_relative 'spec_helper'

describe Sinatra::MultiRoute do
  before do
    count = 0
    mock_app do
      set(:some_condition) { |_| count += 1 }
      register Sinatra::MultiRoute
      get('/') { 'normal' }
      get('/foo', '/bar', :some_condition => true) { 'paths' }
      route('PUT', 'POST', '/') { 'verb' }
      route(:get, '/baz') { 'symbol as verb' }
    end
    @count = count
  end

  it 'does still allow normal routing' do
    get('/').should be_ok
    body.should be == 'normal'
  end

  it 'supports multpile routes' do
    get('/foo').should be_ok
    body.should be == 'paths'
    get('/bar').should be_ok
    body.should be == 'paths'
  end

  it 'triggers conditions' do
    @count.should be == 4
  end

  it 'supports multpile verbs' do
    post('/').should be_ok
    body.should be == 'verb'
    put('/').should be_ok
    body.should be == 'verb'
  end

  it 'takes symbols as verbs' do
    get('/baz').should be_ok
    body.should be == 'symbol as verb'
  end
end