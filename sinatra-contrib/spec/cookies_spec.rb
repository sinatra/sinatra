require 'spec_helper'

describe Sinatra::Cookies do
  def cookie_route(*cookies, &block)
    result = nil
    set_cookie(cookies)
    @cookie_app.get('/') do
      result = instance_eval(&block)
      "ok"
    end
    get '/', {}, @headers || {}
    last_response.should be_ok
    body.should be == "ok"
    result
  end

  def cookies(*set_cookies)
    cookie_route(*set_cookies) { cookies }
  end

  before do
    app = nil
    mock_app do
      helpers Sinatra::Cookies
      app = self
    end
    @cookie_app = app
    clear_cookies
  end

  describe :cookie_route do
    it 'runs the block' do
      ran = false
      cookie_route { ran = true }
      ran.should be true
    end

    it 'returns the block result' do
      cookie_route { 42 }.should be == 42
    end
  end

  describe :== do
    it 'is comparable to hashes' do
      cookies.should be == {}
    end

    it 'is comparable to anything that responds to to_hash' do
      other = Struct.new(:to_hash).new({})
      cookies.should be == other
    end
  end

  describe :[] do
    it 'allows access to request cookies' do
      cookies("foo=bar")["foo"].should be == "bar"
    end

    it 'takes symbols as keys' do
      cookies("foo=bar")[:foo].should be == "bar"
    end

    it 'returns nil for missing keys' do
      cookies("foo=bar")['bar'].should be_nil
    end

    it 'allows access to response cookies' do
      cookie_route do
        response.set_cookie 'foo', 'bar'
        cookies['foo']
      end.should be == 'bar'
    end

    it 'favors response cookies over request cookies' do
      cookie_route('foo=bar') do
        response.set_cookie 'foo', 'baz'
        cookies['foo']
      end.should be == 'baz'
    end


    it 'takes the last value for response cookies' do
      cookie_route do
        response.set_cookie 'foo', 'bar'
        response.set_cookie 'foo', 'baz'
        cookies['foo']
      end.should be == 'baz'
    end
  end

  describe :[]= do
    it 'sets cookies to httponly' do
      cookie_route do
        cookies['foo'] = 'bar'
        response['Set-Cookie'].lines.detect { |l| l.start_with? 'foo=' }
      end.should include('HttpOnly')
    end

    it 'sets domain to nil if localhost' do
      @headers = {'HTTP_HOST' => 'localhost'}
      cookie_route do
        cookies['foo'] = 'bar'
        response['Set-Cookie']
      end.should_not include("domain")
    end

    it 'sets the domain' do
      cookie_route do
        cookies['foo'] = 'bar'
        response['Set-Cookie'].lines.detect { |l| l.start_with? 'foo=' }
      end.should include('domain=example.org')
    end

    it 'sets path to / by default' do
      cookie_route do
        cookies['foo'] = 'bar'
        response['Set-Cookie'].lines.detect { |l| l.start_with? 'foo=' }
      end.should include('path=/')
    end

    it 'sets path to the script_name if app is nested' do
      cookie_route do
        request.script_name = '/foo'
        cookies['foo'] = 'bar'
        response['Set-Cookie'].lines.detect { |l| l.start_with? 'foo=' }
      end.should include('path=/foo')
    end

    it 'sets a cookie' do
      cookie_route { cookies['foo'] = 'bar' }
      cookie_jar['foo'].should be == 'bar'
    end

    it 'adds a value to the cookies hash' do
      cookie_route do
        cookies['foo'] = 'bar'
        cookies['foo']
      end.should be == 'bar'
    end
  end

  describe :assoc do
    it 'behaves like Hash#assoc' do
      cookies('foo=bar').assoc('foo') == ['foo', 'bar']
    end
  end if Hash.method_defined? :assoc

  describe :clear do
    it 'removes request cookies from cookies hash' do
      jar = cookies('foo=bar')
      jar['foo'].should be == 'bar'
      jar.clear
      jar['foo'].should be_nil
    end

    it 'removes response cookies from cookies hash' do
      cookie_route do
        cookies['foo'] = 'bar'
        cookies.clear
        cookies['foo']
      end.should be_nil
    end

    it 'expires existing cookies' do
      cookie_route("foo=bar") do
        cookies.clear
        response['Set-Cookie']
      end.should include("foo=;", "expires=", "1970 00:00:00")
    end
  end

  describe :compare_by_identity? do
    it { cookies.should_not be_compare_by_identity }
  end

  describe :default do
    it { cookies.default.should be_nil }
  end

  describe :default_proc do
    it { cookies.default_proc.should be_nil }
  end

  describe :delete do
    it 'removes request cookies from cookies hash' do
      jar = cookies('foo=bar')
      jar['foo'].should be == 'bar'
      jar.delete 'foo'
      jar['foo'].should be_nil
    end

    it 'removes response cookies from cookies hash' do
      cookie_route do
        cookies['foo'] = 'bar'
        cookies.delete 'foo'
        cookies['foo']
      end.should be_nil
    end

    it 'expires existing cookies' do
      cookie_route("foo=bar") do
        cookies.delete 'foo'
        response['Set-Cookie']
      end.should include("foo=;", "expires=", "1970 00:00:00")
    end

    it 'honours the app cookie_options' do
      @cookie_app.class_eval do
        set :cookie_options, {
          :path => '/foo',
          :domain => 'bar.com',
          :secure => true,
          :httponly => true
        }
      end
      cookie_header = cookie_route("foo=bar") do
        cookies.delete 'foo'
        response['Set-Cookie']
      end
      cookie_header.should include("path=/foo;", "domain=bar.com;", "secure;", "HttpOnly")
    end

    it 'does not touch other cookies' do
      cookie_route("foo=bar", "bar=baz") do
        cookies.delete 'foo'
        cookies['bar']
      end.should be == 'baz'
    end

    it 'returns the previous value for request cookies' do
      cookie_route("foo=bar") do
        cookies.delete "foo"
      end.should be == "bar"
    end

    it 'returns the previous value for response cookies' do
      cookie_route do
        cookies['foo'] = 'bar'
        cookies.delete "foo"
      end.should be == "bar"
    end

    it 'returns nil for non-existing cookies' do
      cookie_route { cookies.delete("foo") }.should be_nil
    end
  end

  describe :delete_if do
    it 'deletes cookies that match the block' do
      cookie_route('foo=bar') do
        cookies['bar'] = 'baz'
        cookies['baz'] = 'foo'
        cookies.delete_if { |*a| a.include? 'bar' }
        cookies.values_at 'foo', 'bar', 'baz'
      end.should be == [nil, nil, 'foo']
    end
  end

  describe :each do
    it 'loops through cookies' do
      keys = []
      foo  = nil
      bar  = nil

      cookie_route('foo=bar', 'bar=baz') do
        cookies.each do |key, value|
          foo = value if key == 'foo'
          bar = value if key == 'bar'
          keys << key
        end
      end

      keys.sort.should be == ['bar', 'foo']
      foo.should be == 'bar'
      bar.should be == 'baz'
    end

    it 'favors response over request cookies' do
      seen = false
      cookie_route('foo=bar') do
        cookies[:foo] = 'baz'
        cookies.each do |key, value|
          key.should   == 'foo'
          value.should == 'baz'
          seen.should == false
          seen = true
        end
      end
    end

    it 'does not loop through deleted cookies' do
      cookie_route('foo=bar') do
        cookies.delete :foo
        cookies.each { fail }
      end
    end

    it 'returns an enumerator' do
      cookie_route('foo=bar') do
        enum = cookies.each
        enum.each { |key, value| key.should == 'foo' }
      end
    end
  end

  describe :each_key do
    it 'loops through cookies' do
      keys = []

      cookie_route('foo=bar', 'bar=baz') do
        cookies.each_key do |key|
          keys << key
        end
      end

      keys.sort.should be == ['bar', 'foo']
    end

    it 'only yields keys once' do
      seen = false
      cookie_route('foo=bar') do
        cookies[:foo] = 'baz'
        cookies.each_key do |key|
          seen.should  == false
          seen = true
        end
      end
    end

    it 'does not loop through deleted cookies' do
      cookie_route('foo=bar') do
        cookies.delete :foo
        cookies.each_key { fail }
      end
    end

    it 'returns an enumerator' do
      cookie_route('foo=bar') do
        enum = cookies.each_key
        enum.each { |key| key.should == 'foo' }
      end
    end
  end

  describe :each_pair do
    it 'loops through cookies' do
      keys = []
      foo  = nil
      bar  = nil

      cookie_route('foo=bar', 'bar=baz') do
        cookies.each_pair do |key, value|
          foo = value if key == 'foo'
          bar = value if key == 'bar'
          keys << key
        end
      end

      keys.sort.should be == ['bar', 'foo']
      foo.should be == 'bar'
      bar.should be == 'baz'
    end

    it 'favors response over request cookies' do
      seen = false
      cookie_route('foo=bar') do
        cookies[:foo] = 'baz'
        cookies.each_pair do |key, value|
          key.should   == 'foo'
          value.should == 'baz'
          seen.should  == false
          seen = true
        end
      end
    end

    it 'does not loop through deleted cookies' do
      cookie_route('foo=bar') do
        cookies.delete :foo
        cookies.each_pair { fail }
      end
    end

    it 'returns an enumerator' do
      cookie_route('foo=bar') do
        enum = cookies.each_pair
        enum.each { |key, value| key.should == 'foo' }
      end
    end
  end

  describe :each_value do
    it 'loops through cookies' do
      values = []

      cookie_route('foo=bar', 'bar=baz') do
        cookies.each_value do |value|
          values << value
        end
      end

      values.sort.should be == ['bar', 'baz']
    end

    it 'favors response over request cookies' do
      seen = false
      cookie_route('foo=bar') do
        cookies[:foo] = 'baz'
        cookies.each_value do |value|
          value.should == 'baz'
          seen.should  == false
          seen = true
        end
      end
    end

    it 'does not loop through deleted cookies' do
      cookie_route('foo=bar') do
        cookies.delete :foo
        cookies.each_value { fail }
      end
    end

    it 'returns an enumerator' do
      cookie_route('foo=bar') do
        enum = cookies.each_value
        enum.each { |value| value.should == 'bar' }
      end
    end
  end

  describe :empty? do
    it 'returns true if there are no cookies' do
      cookies.should be_empty
    end

    it 'returns false if there are request cookies' do
      cookies('foo=bar').should_not be_empty
    end

    it 'returns false if there are response cookies' do
      cookie_route do
        cookies['foo'] = 'bar'
        cookies.empty?
      end.should be false
    end

    it 'becomes true if response cookies are removed' do
      cookie_route do
        cookies['foo'] = 'bar'
        cookies.delete :foo
        cookies.empty?
      end.should be true
    end

    it 'becomes true if request cookies are removed' do
      cookie_route('foo=bar') do
        cookies.delete :foo
        cookies.empty?
      end.should be_truthy
    end

    it 'becomes true after clear' do
      cookie_route('foo=bar', 'bar=baz') do
        cookies['foo'] = 'bar'
        cookies.clear
        cookies.empty?
      end.should be_truthy
    end
  end

  describe :fetch do
    it 'returns values from request cookies' do
      cookies('foo=bar').fetch('foo').should be == 'bar'
    end

    it 'returns values from response cookies' do
      cookie_route do
        cookies['foo'] = 'bar'
        cookies.fetch('foo')
      end.should be == 'bar'
    end

    it 'favors response over request cookies' do
      cookie_route('foo=baz') do
        cookies['foo'] = 'bar'
        cookies.fetch('foo')
      end.should be == 'bar'
    end

    it 'raises an exception if key does not exist' do
      error = if defined? JRUBY_VERSION
        IndexError
      else
        RUBY_VERSION >= '1.9' ? KeyError : IndexError
      end
      expect { cookies.fetch('foo') }.to raise_exception(error)
    end

    it 'returns the block result if missing' do
      cookies.fetch('foo') { 'bar' }.should be == 'bar'
    end
  end

  describe :flatten do
    it { cookies('foo=bar').flatten.should be == {'foo' => 'bar'}.flatten }
  end if Hash.method_defined? :flatten

  describe :has_key? do
    it 'checks request cookies' do
      cookies('foo=bar').should have_key('foo')
    end

    it 'checks response cookies' do
      jar = cookies
      jar['foo'] = 'bar'
      jar.should have_key(:foo)
    end

    it 'does not use deleted cookies' do
      jar = cookies('foo=bar')
      jar.delete :foo
      jar.should_not have_key('foo')
    end
  end

  describe :has_value? do
    it 'checks request cookies' do
      cookies('foo=bar').should have_value('bar')
    end

    it 'checks response cookies' do
      jar = cookies
      jar[:foo] = 'bar'
      jar.should have_value('bar')
    end

    it 'does not use deleted cookies' do
      jar = cookies('foo=bar')
      jar.delete :foo
      jar.should_not have_value('bar')
    end
  end

  describe :include? do
    it 'checks request cookies' do
      cookies('foo=bar').should include('foo')
    end

    it 'checks response cookies' do
      jar = cookies
      jar['foo'] = 'bar'
      jar.should include(:foo)
    end

    it 'does not use deleted cookies' do
      jar = cookies('foo=bar')
      jar.delete :foo
      jar.should_not include('foo')
    end
  end

  describe :index do
    it 'checks request cookies' do
      cookies('foo=bar').index('bar').should be == 'foo'
    end

    it 'checks response cookies' do
      jar = cookies
      jar['foo'] = 'bar'
      jar.index('bar').should be == 'foo'
    end

    it 'returns nil when missing' do
      cookies('foo=bar').index('baz').should be_nil
    end
  end if RUBY_VERSION < '1.9'

  describe :keep_if do
    it 'removes entries' do
      jar = cookies('foo=bar', 'bar=baz')
      jar.keep_if { |*args| args == ['bar', 'baz'] }
      jar.should be == {'bar' => 'baz'}
    end
  end

  describe :key do
    it 'checks request cookies' do
      cookies('foo=bar').key('bar').should be == 'foo'
    end

    it 'checks response cookies' do
      jar = cookies
      jar['foo'] = 'bar'
      jar.key('bar').should be == 'foo'
    end

    it 'returns nil when missing' do
      cookies('foo=bar').key('baz').should be_nil
    end
  end

  describe :key? do
    it 'checks request cookies' do
      cookies('foo=bar').key?('foo').should be true
    end

    it 'checks response cookies' do
      jar = cookies
      jar['foo'] = 'bar'
      jar.key?(:foo).should be true
    end

    it 'does not use deleted cookies' do
      jar = cookies('foo=bar')
      jar.delete :foo
      jar.key?('foo').should be false
    end
  end

  describe :keys do
    it { cookies('foo=bar').keys.should == ['foo'] }
  end

  describe :length do
    it { cookies.length.should == 0 }
    it { cookies('foo=bar').length.should == 1 }
  end

  describe :member? do
    it 'checks request cookies' do
      cookies('foo=bar').member?('foo').should be true
    end

    it 'checks response cookies' do
      jar = cookies
      jar['foo'] = 'bar'
      jar.member?(:foo).should be true
    end

    it 'does not use deleted cookies' do
      jar = cookies('foo=bar')
      jar.delete :foo
      jar.member?('foo').should be false
    end
  end

  describe :merge do
    it 'is mergable with a hash' do
      cookies('foo=bar').merge(:bar => :baz).should be == {"foo" => "bar", :bar => :baz}
    end

    it 'does not create cookies' do
      jar = cookies('foo=bar')
      jar.merge(:bar => 'baz')
      jar.should_not include(:bar)
    end

    it 'takes a block for conflict resolution' do
      update = {'foo' => 'baz', 'bar' => 'baz'}
      merged = cookies('foo=bar').merge(update) do |key, old, other|
        key.should   be == 'foo'
        old.should   be == 'bar'
        other.should be == 'baz'
        'foo'
      end
      merged['foo'].should be == 'foo'
    end
  end

  describe :merge! do
    it 'creates cookies' do
      jar = cookies('foo=bar')
      jar.merge! :bar => 'baz'
      jar.should include('bar')
    end

    it 'overrides existing values' do
      jar = cookies('foo=bar')
      jar.merge! :foo => "baz"
      jar["foo"].should be == "baz"
    end

    it 'takes a block for conflict resolution' do
      update = {'foo' => 'baz', 'bar' => 'baz'}
      jar    = cookies('foo=bar')
      jar.merge!(update) do |key, old, other|
        key.should   be == 'foo'
        old.should   be == 'bar'
        other.should be == 'baz'
        'foo'
      end
      jar['foo'].should be == 'foo'
    end
  end

  describe :rassoc do
    it 'behaves like Hash#assoc' do
      cookies('foo=bar').rassoc('bar') == ['foo', 'bar']
    end
  end if Hash.method_defined? :rassoc

  describe :reject do
    it 'removes entries from new hash' do
      jar = cookies('foo=bar', 'bar=baz')
      sub = jar.reject { |*args| args == ['bar', 'baz'] }
      sub.should be == {'foo' => 'bar'}
      jar['bar'].should be == 'baz'
    end
  end

  describe :reject! do
    it 'removes entries' do
      jar = cookies('foo=bar', 'bar=baz')
      jar.reject! { |*args| args == ['bar', 'baz'] }
      jar.should be == {'foo' => 'bar'}
    end
  end

  describe :replace do
    it 'replaces entries' do
      jar = cookies('foo=bar', 'bar=baz')
      jar.replace 'foo' => 'baz', 'baz' => 'bar'
      jar.should be == {'foo' => 'baz', 'baz' => 'bar'}
    end
  end

  describe :select do
    it 'removes entries from new hash' do
      jar = cookies('foo=bar', 'bar=baz')
      sub = jar.select { |*args| args != ['bar', 'baz'] }
      sub.should be == {'foo' => 'bar'}.select { true }
      jar['bar'].should be == 'baz'
    end
  end

  describe :select! do
    it 'removes entries' do
      jar = cookies('foo=bar', 'bar=baz')
      jar.select! { |*args| args != ['bar', 'baz'] }
      jar.should be == {'foo' => 'bar'}
    end
  end if Hash.method_defined? :select!

  describe :shift do
    it 'removes from the hash' do
      jar = cookies('foo=bar')
      jar.shift.should be == ['foo', 'bar']
      jar.should_not include('bar')
    end
  end

  describe :size do
    it { cookies.size.should == 0 }
    it { cookies('foo=bar').size.should == 1 }
  end

  describe :update do
    it 'creates cookies' do
      jar = cookies('foo=bar')
      jar.update :bar => 'baz'
      jar.should include('bar')
    end

    it 'overrides existing values' do
      jar = cookies('foo=bar')
      jar.update :foo => "baz"
      jar["foo"].should be == "baz"
    end

    it 'takes a block for conflict resolution' do
      merge = {'foo' => 'baz', 'bar' => 'baz'}
      jar   = cookies('foo=bar')
      jar.update(merge) do |key, old, other|
        key.should   be == 'foo'
        old.should   be == 'bar'
        other.should be == 'baz'
        'foo'
      end
      jar['foo'].should be == 'foo'
    end
  end

  describe :value? do
    it 'checks request cookies' do
      cookies('foo=bar').value?('bar').should be true
    end

    it 'checks response cookies' do
      jar = cookies
      jar[:foo] = 'bar'
      jar.value?('bar').should be true
    end

    it 'does not use deleted cookies' do
      jar = cookies('foo=bar')
      jar.delete :foo
      jar.value?('bar').should be false
    end
  end

  describe :values do
    it { cookies('foo=bar', 'bar=baz').values.sort.should be == ['bar', 'baz'] }
  end

  describe :values_at do
    it { cookies('foo=bar', 'bar=baz').values_at('foo').should be == ['bar'] }
  end
end
