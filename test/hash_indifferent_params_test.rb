require File.expand_path('../helper', __FILE__)

class BaseTest < Test::Unit::TestCase

  setup do
    @hash = {"some_key" => "moshe"}
  end

  it 'allows accessing hash with string key' do
    parsed_hash =  Sinatra::Base.new.helpers.send(:indifferent_params,  @hash)
    assert_equal "moshe" , parsed_hash["some_key"]
  end

  it 'allows accessing hash with symbol as key' do
    parsed_hash =  Sinatra::Base.new.helpers.send(:indifferent_params,  @hash)
    assert_equal "moshe" , parsed_hash[:some_key]
  end

  it 'allows accessing hash with fetch symbol as key' do
    parsed_hash =  Sinatra::Base.new.helpers.send(:indifferent_params,  @hash)
    assert_equal "moshe" , parsed_hash.fetch(:some_key, "wrong_value")
  end

  it 'allows accessing hash with fetch symbol as key' do
    parsed_hash =  Sinatra::Base.new.helpers.send(:indifferent_params,  @hash)
    assert_equal "moshe" , parsed_hash.fetch("some_key", "wrong_value")
  end

end
