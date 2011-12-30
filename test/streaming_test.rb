require File.expand_path('../helper', __FILE__)

class StreamingTest < Test::Unit::TestCase
  Stream = Sinatra::Helpers::Stream

  it 'returns the concatinated body' do
    mock_app do
      get '/' do
        stream do |out|
          out << "Hello" << " "
          out << "World!"
        end
      end
    end

    get('/')
    assert_body "Hello World!"
  end

  it 'always yields strings' do
    stream = Stream.new { |out| out << :foo }
    stream.each { |str| assert_equal 'foo', str }
  end

  it 'postpones body generation' do
    step = 0

    stream = Stream.new do |out|
      10.times do
        out << step
        step += 1
      end
    end

    stream.each do |s|
      assert_equal s, step.to_s
      step += 1
    end
  end

  it 'calls the callback after it is done' do
    step   = 0
    final  = 0
    stream = Stream.new { |o| 10.times { step += 1 }}
    stream.callback { final = step }
    stream.each { |str| }
    assert_equal 10, final
  end

  it 'does not trigger the callback if close is set to :keep_open' do
    step   = 0
    final  = 0
    stream = Stream.new(Stream, :keep_open) { |o| 10.times { step += 1 } }
    stream.callback { final = step }
    stream.each { |str| }
    assert_equal 0, final
  end

  it 'allows adding more than one callback' do
    a = b = false
    stream = Stream.new { }
    stream.callback { a = true }
    stream.callback { b = true }
    stream.each { |str| }
    assert a, 'should trigger first callback'
    assert b, 'should trigger second callback'
  end

  class MockScheduler
    def initialize(*)     @schedule, @defer = [], []                end
    def schedule(&block)  @schedule << block                        end
    def defer(&block)     @defer    << block                        end
    def schedule!(*)      @schedule.pop.call until @schedule.empty? end
    def defer!(*)         @defer.pop.call    until @defer.empty?    end
  end

  it 'allows dropping in another scheduler' do
    scheduler  = MockScheduler.new
    processing = sending = done = false

    stream = Stream.new(scheduler) do |out|
      processing = true
      out << :foo
    end

    stream.each { sending = true}
    stream.callback { done = true }

    scheduler.schedule!
    assert !processing
    assert !sending
    assert !done

    scheduler.defer!
    assert processing
    assert !sending
    assert !done

    scheduler.schedule!
    assert sending
    assert done
  end

  it 'schedules exceptions to be raised on the main thread/event loop/...' do
    scheduler = MockScheduler.new
    Stream.new(scheduler) { fail 'should be caught' }.each { }
    scheduler.defer!
    assert_raise(RuntimeError) { scheduler.schedule! }
  end

  it 'does not trigger an infinite loop if you call close in a callback' do
    stream = Stream.new { |out| out.callback { out.close }}
    stream.each { |str| }
  end

  it 'gives access to route specific params' do
    mock_app do
      get('/:name') { stream { |o| o << params[:name] }}
    end
    get '/foo'
    assert_body 'foo'
  end
end
