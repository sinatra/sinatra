require 'spec_helper'

RSpec.describe Sinatra::MultiRoute do

  it 'does not break normal routing' do
    mock_app do
      register Sinatra::MultiRoute
      get('/') { 'normal' }
    end

    expect(get('/')).to be_ok
    expect(body).to eq('normal')
  end

  it 'supports multiple routes' do
    mock_app do
      register Sinatra::MultiRoute
      get('/foo', '/bar') { 'paths' }
    end

    expect(get('/foo')).to be_ok
    expect(body).to eq('paths')
    expect(get('/bar')).to be_ok
    expect(body).to eq('paths')
  end

  it 'triggers conditions' do
    count = 0
    mock_app do
      register Sinatra::MultiRoute
      set(:some_condition) { |_| count += 1 }
      get('/foo', '/bar', :some_condition => true) { 'paths' }
    end

    expect(count).to eq(4)
  end

  it 'supports multiple verbs' do
    mock_app do
      register Sinatra::MultiRoute
      route('PUT', 'POST', '/') { 'verb' }
    end

    expect(post('/')).to be_ok
    expect(body).to eq('verb')
    expect(put('/')).to be_ok
    expect(body).to eq('verb')
  end

  it 'takes symbols as verbs' do
    mock_app do
      register Sinatra::MultiRoute
      route(:get, '/baz') { 'symbol as verb' }
    end

    expect(get('/baz')).to be_ok
    expect(body).to eq('symbol as verb')
  end
end
