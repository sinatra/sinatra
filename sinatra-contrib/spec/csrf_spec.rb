require 'backports'
require_relative 'spec_helper'

describe Sinatra::CSRF do
  safe   = %w[get options]
  unsafe = %w[post put delete]
  unsafe << "patch" if Sinatra::Base.respond_to? :patch

  before do
    mock_app do
      register Sinatra::CSRF
      set :csrf_protection, checks
      (safe + unsafe).each { |v| send(v, '/') { 'ok' }}
      get('/token') { authenticity_token }
      get('/tag') { authenticity_tag }
    end
  end

  describe 'optional referrer' do
    let(:checks) { :optional_referrer }
    it 'allows get request'
    it 'prevents requests from a different host'
    it 'allows requests from the same host'
    it 'allows requests with no referrer'
  end

  describe 'referrer' do
    let(:checks) { :referrer }
    it 'prevents requests from a different host'
    it 'allows requests from the same host'
    it 'prevents requests with no referrer'
  end

  describe 'token' do
    let(:checks) { :token }
    it 'prevents normal requests without a valid token'
    it 'prevents ajax requests without a valid token'
    it 'allows normal requests with a valid token'
    it 'allows ajax requests with a valid token'
  end

  describe 'form' do
    let(:checks) { :form }
    it 'prevents normal requests without a valid token'
    it 'allows ajax requests without a valid token'
    it 'allows normal requests with a valid token'
    it 'allows ajax requests with a valid token'
  end
end
