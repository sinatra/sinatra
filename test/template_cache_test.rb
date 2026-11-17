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

  it 'is safe when multiple threads race to fill the same key' do
    # release all threads together, and have each pause mid-block so their
    # fetches genuinely overlap instead of resolving one at a time
    start = Queue.new
    threads = Array.new(20) do |i|
      Thread.new do
        start.pop
        @cache.fetch(:key) do
          Thread.pass
          i
        end
      end
    end
    20.times { start << true }
    results = threads.map(&:value)

    # a racing thread either computed its own value or read back whichever
    # value had already won the write - either way, never something else
    results.each { |result| assert_includes 0...20, result }

    # exactly one value ends up cached, and it stays that way
    winner = @cache.fetch(:key) { raise 'should have been cached' }
    assert_includes results, winner
    assert_equal winner, @cache.fetch(:key) { raise 'should have been cached' }
  end

  it 'is safe to clear the cache while another thread is filling it' do
    ready = Queue.new
    filler = Thread.new { @cache.fetch(:key) { ready.pop; :original } }
    ready << true
    @cache.clear
    filler.value # re-raises if the filler thread raised

    # whichever ordering won the race, the cache is left in a consistent
    # state: either still holding :original, or clear()'d it out entirely
    assert_includes [:original, :recomputed], @cache.fetch(:key) { :recomputed }
  end
end
