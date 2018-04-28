# frozen_string_literal: true
#
# We don't need the full test helper for this standalone class.
#
require 'minitest/autorun' unless defined?(Minitest)

require_relative '../lib/sinatra/indifferent_hash'

class TestIndifferentHashBasics < Minitest::Test
  def test_flattened_constructor
    hash = Sinatra::IndifferentHash[:a, 1, ?b, 2]
    assert_equal 1, hash[?a]
    assert_equal 2, hash[?b]
  end

  def test_pairs_constructor
    hash = Sinatra::IndifferentHash[[[:a, 1], [?b, 2]]]
    assert_equal 1, hash[?a]
    assert_equal 2, hash[?b]
  end

  def test_default_block
    hash = Sinatra::IndifferentHash.new { |h, k| h[k] = k.upcase }
    assert_nil hash.default
    assert_equal ?A, hash.default(:a)
  end

  def test_default_object
    hash = Sinatra::IndifferentHash.new(:a=>1, ?b=>2)
    assert_equal({ ?a=>1, ?b=>2 }, hash.default)
    assert_equal({ ?a=>1, ?b=>2 }, hash[:a])
  end

  def test_default_assignment
    hash = Sinatra::IndifferentHash.new
    hash.default = { :a=>1, ?b=>2 }
    assert_equal({ ?a=>1, ?b=>2 }, hash.default)
    assert_equal({ ?a=>1, ?b=>2 }, hash[:a])
  end

  def test_assignment
    hash = Sinatra::IndifferentHash.new
    hash[:a] = :a
    hash[?b] = :b
    hash[3] = 3
    hash[:simple_nested] = { :a=>:a, ?b=>:b }

    assert_equal :a, hash[?a]
    assert_equal :b, hash[?b]
    assert_equal 3, hash[3]
    assert_equal({ ?a=>:a, ?b=>:b }, hash['simple_nested'])
    assert_nil hash[?d]
  end

  def test_merge!
    # merge! is already mostly tested by the different constructors, so we
    # really just need to test the block form here
    hash = Sinatra::IndifferentHash[:a=>'a', ?b=>'b', 3=>3]
    hash.merge!(?a=>'A', :b=>'B', :d=>'D') do |key, oldval, newval|
      "#{oldval}*#{key}*#{newval}"
    end

    assert_equal({ ?a=>'a*a*A', ?b=>'b*b*B', 3=>3, ?d=>'D' }, hash)
  end
end

class TestIndifferentHash < Minitest::Test
  def skip_if_lacking(meth)
    skip "Hash##{meth} not supported on this Ruby" unless Hash.method_defined?(meth)
  end

  def setup
    @hash = Sinatra::IndifferentHash[:a=>:a, ?b=>:b, 3=>3,
      :simple_nested=>{ :a=>:a, ?b=>:b },
      :nested=>{ :a=>[{ :a=>:a, ?b=>:b }, :c, 4], ?f=>:f, 7=>7 }
    ]
  end

  def test_hash_constructor
    assert_equal :a, @hash[?a]
    assert_equal :b, @hash[?b]
    assert_equal 3, @hash[3]
    assert_equal({ ?a=>:a, ?b=>:b }, @hash['nested'][?a][0])
    assert_equal :c, @hash['nested'][?a][1]
    assert_equal 4, @hash['nested'][?a][2]
    assert_equal :f, @hash['nested'][?f]
    assert_equal 7, @hash['nested'][7]
    assert_equal :a, @hash['simple_nested'][?a]
    assert_equal :b, @hash['simple_nested'][?b]
    assert_nil @hash[?d]
  end

  def test_assoc
    assert_nil @hash.assoc(:d)
    assert_equal [?a, :a], @hash.assoc(:a)
    assert_equal [?b, :b], @hash.assoc(:b)
  end

  def test_rassoc
    assert_nil @hash.rassoc(:d)
    assert_equal [?a, :a], @hash.rassoc(:a)
    assert_equal [?b, :b], @hash.rassoc(:b)
    assert_equal ['simple_nested', { ?a=>:a, ?b=>:b }], @hash.rassoc(:a=>:a, ?b=>:b)
  end

  def test_fetch
    assert_raises(KeyError) { @hash.fetch(:d) }
    assert_equal 1, @hash.fetch(:d, 1)
    assert_equal 2, @hash.fetch(:d) { 2 }
    assert_equal ?d, @hash.fetch(:d) { |k| k }
    assert_equal :a, @hash.fetch(:a, 1)
    assert_equal :a, @hash.fetch(:a) { 2 }
  end

  def test_symbolic_retrieval
    assert_equal :a, @hash[:a]
    assert_equal :b, @hash[:b]
    assert_equal({ ?a=>:a, ?b=>:b }, @hash[:nested][:a][0])
    assert_equal :c, @hash[:nested][:a][1]
    assert_equal 4, @hash[:nested][:a][2]
    assert_equal :f, @hash[:nested][:f]
    assert_equal 7, @hash[:nested][7]
    assert_equal :a, @hash[:simple_nested][:a]
    assert_equal :b, @hash[:simple_nested][:b]
    assert_nil @hash[:d]
  end

  def test_key
    assert_nil @hash.key(:d)
    assert_equal ?a, @hash.key(:a)
    assert_equal 'simple_nested', @hash.key(:a=>:a, ?b=>:b)
  end

  def test_key?
    assert_operator @hash, :key?, :a
    assert_operator @hash, :key?, ?b
    assert_operator @hash, :key?, 3
    refute_operator @hash, :key?, :d
  end

  def test_value?
    assert_operator @hash, :value?, :a
    assert_operator @hash, :value?, :b
    assert_operator @hash, :value?, 3
    assert_operator @hash, :value?, { :a=>:a, ?b=>:b }
    refute_operator @hash, :value?, :d
  end

  def test_delete
    @hash.delete(:a)
    @hash.delete(?b)
    assert_nil @hash[:a]
    assert_nil @hash[?b]
  end

  def test_dig
    skip_if_lacking :dig

    assert_equal :a, @hash.dig(:a)
    assert_equal :b, @hash.dig(?b)
    assert_nil @hash.dig(:d)

    assert_equal :a, @hash.dig(:simple_nested, :a)
    assert_equal :b, @hash.dig('simple_nested', ?b)
    assert_nil @hash.dig('simple_nested', :d)

    assert_equal :a, @hash.dig(:nested, :a, 0, :a)
    assert_equal :b, @hash.dig('nested', ?a, 0, ?b)
    assert_nil @hash.dig('nested', ?a, 0, :d)
  end

  def test_slice
    skip_if_lacking :slice

    assert_equal Sinatra::IndifferentHash[a: :a], @hash.slice(:a)
    assert_equal Sinatra::IndifferentHash[b: :b], @hash.slice(?b)
    assert_equal Sinatra::IndifferentHash[3 => 3], @hash.slice(3)
    assert_equal Sinatra::IndifferentHash.new, @hash.slice(:d)
    assert_equal Sinatra::IndifferentHash[a: :a, b: :b, 3 => 3], @hash.slice(:a, :b, 3)
    assert_equal Sinatra::IndifferentHash[simple_nested: { a: :a, ?b => :b }], @hash.slice(:simple_nested)
    assert_equal Sinatra::IndifferentHash[nested: { a: [{ a: :a, ?b => :b }, :c, 4], ?f => :f, 7 => 7 }], @hash.slice(:nested)
  end

  def test_fetch_values
    skip_if_lacking :fetch_values

    assert_raises(KeyError) { @hash.fetch_values(3, :d) }
    assert_equal [:a, :b, 3, ?D], @hash.fetch_values(:a, ?b, 3, :d) { |k| k.upcase }
  end

  def test_values_at
    assert_equal [:a, :b, 3, nil], @hash.values_at(:a, ?b, 3, :d)
  end

  def test_merge
    # merge just calls merge!, which is already thoroughly tested
    hash2 = @hash.merge(?a=>1, :q=>2) { |key, oldval, newval| "#{oldval}*#{key}*#{newval}" }

    refute_equal @hash, hash2
    assert_equal 'a*a*1', hash2[:a]
    assert_equal 2, hash2[?q]
  end

  def test_replace
    @hash.replace(?a=>1, :q=>2)
    assert_equal({ ?a=>1, ?q=>2 }, @hash)
  end
end
