# frozen_string_literal: true

RSpec.describe Rack::Protection::Base do
  subject { described_class.new(-> {}) }

  describe '#random_string' do
    it 'outputs a string of 32 characters' do
      expect(subject.random_string.length).to eq(32)
    end
  end

  describe '#referrer' do
    it 'Reads referrer from Referer header' do
      env = { 'HTTP_HOST' => 'foo.com', 'HTTP_REFERER' => 'http://bar.com/valid' }
      expect(subject.referrer(env)).to eq('bar.com')
    end

    it 'Reads referrer from Host header when Referer header is relative' do
      env = { 'HTTP_HOST' => 'foo.com', 'HTTP_REFERER' => '/valid' }
      expect(subject.referrer(env)).to eq('foo.com')
    end

    it 'Reads referrer from Host header when Referer header is missing' do
      env = { 'HTTP_HOST' => 'foo.com' }
      expect(subject.referrer(env)).to eq('foo.com')
    end

    it 'Returns nil when Referer header is missing and allow_empty_referrer is false' do
      env = { 'HTTP_HOST' => 'foo.com' }
      subject.options[:allow_empty_referrer] = false
      expect(subject.referrer(env)).to be_nil
    end

    it 'Returns nil when Referer header is invalid' do
      env = { 'HTTP_HOST' => 'foo.com', 'HTTP_REFERER' => 'http://bar.com/bad|uri' }
      expect(subject.referrer(env)).to be_nil
    end
  end
end
