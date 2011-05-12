require 'backports'
require_relative 'spec_helper'

describe Sinatra::CSRF do
  SAFE   = %w[get options]
  UNSAFE = %w[post put delete]
  UNSAFE << "patch" if Sinatra::Base.respond_to? :patch

  def self.checks(*list)
    before do
      mock_app do
        register Sinatra::CSRF
        set :csrf_protection, list
        (SAFE + UNSAFE).each { |v| send(v, '/') { 'ok' }}
        get('/token') { authenticity_token }
        get('/tag') { authenticity_tag }
      end
    end
  end

  describe 'optional referrer' do
    checks :optional_referrer

    UNSAFE.each do |verb|
      it "prevents #{verb} requests from a different host" do
        send(verb, '/', {}, 'HTTP_REFERER' => 'http://google.com')
        last_response.should_not be_ok
      end

      it "allows #{verb} requests from the same host" do
        send(verb, '/', {}, 'HTTP_REFERER' => 'http://example.org')
        last_response.should be_ok
      end

      it "allows #{verb} requests with no referrer" do
        send(verb, '/')
        last_response.should be_ok
      end
    end

    SAFE.each do |verb|
      it "allows #{verb} requests from a different host" do
        send(verb, '/', {}, 'HTTP_REFERER' => 'http://google.com')
        last_response.should be_ok
      end

      it "allows #{verb} requests from the same host" do
        send(verb, '/', {}, 'HTTP_REFERER' => 'http://example.org')
        last_response.should be_ok
      end

      it "allows #{verb} requests with no referrer" do
        send(verb, '/', {}, 'HTTP_REFERER' => '')
        last_response.should be_ok
      end
    end
  end

  describe 'referrer' do
    checks :referrer

    UNSAFE.each do |verb|
      it "prevents #{verb} requests from a different host" do
        send(verb, '/', {}, 'HTTP_REFERER' => 'http://google.com')
        last_response.should_not be_ok
      end

      it "allows #{verb} requests from the same host" do
        send(verb, '/', {}, 'HTTP_REFERER' => 'http://example.org')
        last_response.should be_ok
      end

      it "allows #{verb} requests with no referrer" do
        send(verb, '/', {}, 'HTTP_REFERER' => '')
        last_response.should_not be_ok
      end
    end

    SAFE.each do |verb|
      it "allows #{verb} requests from a different host" do
        send(verb, '/', {}, 'HTTP_REFERER' => 'http://google.com')
        last_response.should be_ok
      end

      it "allows #{verb} requests from the same host" do
        send(verb, '/', {}, 'HTTP_REFERER' => 'http://example.org')
        last_response.should be_ok
      end

      it "allows #{verb} requests with no referrer" do
        send(verb, '/', {}, 'HTTP_REFERER' => '')
        last_response.should be_ok
      end
    end
  end

  describe 'token' do
    checks :token
    it 'prevents normal requests without a valid token'
    it 'prevents ajax requests without a valid token'
    it 'allows normal requests with a valid token'
    it 'allows ajax requests with a valid token'
  end

  describe 'form' do
    checks :form
    it 'prevents normal requests without a valid token'
    it 'allows ajax requests without a valid token'
    it 'allows normal requests with a valid token'
    it 'allows ajax requests with a valid token'
  end
end
