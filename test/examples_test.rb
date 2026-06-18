# frozen_string_literal: true

require_relative 'test_helper'
require 'rack'

# Guards the shipped examples against drifting from the code. If the streaming
# API changes incompatibly, these fail instead of the examples silently rotting.
class ExamplesTest < Minitest::Test
  include Rack::Test::Methods

  EXAMPLES = File.expand_path('../examples', __dir__)

  # All examples must at least parse under the current code.
  it 'all examples have valid syntax' do
    Dir[File.join(EXAMPLES, '*.{rb,ru}')].each do |file|
      assert RubyVM::InstructionSequence.compile(File.read(file), file),
             "#{File.basename(file)} failed to compile"
    end
  end

  # examples/stream.ru exercises the basic `stream`/`out <<` path end to end. Its
  # producer is finite, so Rack::Test can drive the callable body to completion.
  it 'stream.ru streams its body through the real streaming API' do
    skip_unless_rack_buffers_callable_body
    app, = Rack::Builder.parse_file(File.join(EXAMPLES, 'stream.ru'))
    response = Rack::MockRequest.new(app).get('/')
    assert_equal 200, response.status
    assert_includes response.body, 'legen'
    assert_includes response.body, 'dary'
  end

  # examples/sse.rb is modular (it only runs under a real server when executed
  # directly), so requiring it is safe and exercises the class definition,
  # on_stream_error registration, and its non-streaming route.
  it 'sse.rb boots and serves its page' do
    require File.join(EXAMPLES, 'sse')
    @app = SSEExample
    get '/'
    assert last_response.ok?
    assert_includes last_response.body, 'EventSource'
  end

  def app
    @app
  end
end
