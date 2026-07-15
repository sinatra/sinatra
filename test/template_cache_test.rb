require_relative 'test_helper'

class TemplateCacheTest < Minitest::Test
  def setup
    @cache = Sinatra::TemplateCache.new
  end

  it 'caches the value returned by the block under the given key' do
    assert_equal 'value', @cache.fetch(:key) { 'value' }
    assert_equal 'value', @cache.fetch(:key) { raise 'should not be called' }
  end

  it 'accepts multiple objects as a single cache key' do
    @cache.fetch(:a, :b) { 'value' }
    assert_equal 'value', @cache.fetch(:a, :b) { raise 'should not be called' }
  end

  it 'clears all cached values' do
    @cache.fetch(:key) { 'value' }
    @cache.clear
    assert_equal 'new value', @cache.fetch(:key) { 'new value' }
  end

  it 'is safe to read and write from multiple threads at once' do
    threads = Array.new(20) do |i|
      Thread.new do
        100.times { |j| @cache.fetch(i, j) { [i, j] } }
      end
    end
    threads.each(&:join)

    20.times do |i|
      100.times do |j|
        assert_equal [i, j], @cache.fetch(i, j) { raise 'should have been cached' }
      end
    end
  end
end
