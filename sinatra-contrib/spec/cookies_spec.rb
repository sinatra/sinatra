require 'spec_helper'

RSpec.describe Sinatra::Cookies do
  def cookie_route(*cookies, headers: {}, &block)
    result = nil
    set_cookie(cookies)
    @cookie_app.get('/') do
      result = instance_eval(&block)
      "ok"
    end
    get '/', {}, headers || {}
    expect(last_response).to be_ok
    expect(body).to eq("ok")
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
      expect(ran).to be true
    end

    it 'returns the block result' do
      expect(cookie_route { 42 }).to eq(42)
    end
  end

  describe :== do
    it 'is comparable to hashes' do
      expect(cookies).to eq({})
    end

    it 'is comparable to anything that responds to to_hash' do
      other = Struct.new(:to_hash).new({})
      expect(cookies).to eq(other)
    end
  end

  describe :[] do
    it 'allows access to request cookies' do
      expect(cookies("foo=bar")["foo"]).to eq("bar")
    end

    it 'takes symbols as keys' do
      expect(cookies("foo=bar")[:foo]).to eq("bar")
    end

    it 'returns nil for missing keys' do
      expect(cookies("foo=bar")['bar']).to be_nil
    end

    it 'allows access to response cookies' do
      expect(cookie_route do
        response.set_cookie 'foo', 'bar'
        cookies['foo']
      end).to eq('bar')
    end

    it 'favors response cookies over request cookies' do
      expect(cookie_route('foo=bar') do
        response.set_cookie 'foo', 'baz'
        cookies['foo']
      end).to eq('baz')
    end


    it 'takes the last value for response cookies' do
      expect(cookie_route do
        response.set_cookie 'foo', 'bar'
        response.set_cookie 'foo', 'baz'
        cookies['foo']
      end).to eq('baz')
    end
  end

  describe :[]= do
    it 'sets cookies to httponly' do
      expect(cookie_route do
        cookies['foo'] = 'bar'
        response['Set-Cookie'].lines.detect { |l| l.start_with? 'foo=' }
      end).to include('httponly')
    end

    it 'sets domain to nil if localhost' do
      headers = {'HTTP_HOST' => 'localhost'}
      expect(cookie_route(headers: headers) do
        cookies['foo'] = 'bar'
        response['Set-Cookie']
      end).not_to include("domain")
    end

    it 'sets the domain' do
      expect(cookie_route do
        cookies['foo'] = 'bar'
        response['Set-Cookie'].lines.detect { |l| l.start_with? 'foo=' }
      end).to include('domain=example.org')
    end

    it 'sets path to / by default' do
      expect(cookie_route do
        cookies['foo'] = 'bar'
        response['Set-Cookie'].lines.detect { |l| l.start_with? 'foo=' }
      end).to include('path=/')
    end

    it 'sets path to the script_name if app is nested' do
      expect(cookie_route do
        request.script_name = '/foo'
        cookies['foo'] = 'bar'
        response['Set-Cookie'].lines.detect { |l| l.start_with? 'foo=' }
      end).to include('path=/foo')
    end

    it 'sets a cookie' do
      cookie_route { cookies['foo'] = 'bar' }
      expect(cookie_jar['foo']).to eq('bar')
    end

    it 'adds a value to the cookies hash' do
      expect(cookie_route do
        cookies['foo'] = 'bar'
        cookies['foo']
      end).to eq('bar')
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
      expect(jar['foo']).to eq('bar')
      jar.clear
      expect(jar['foo']).to be_nil
    end

    it 'does not remove response cookies from cookies hash' do
      expect(cookie_route do
        cookies['foo'] = 'bar'
        cookies.clear
        cookies['foo']
      end).to eq('bar')
    end

    it 'expires existing cookies' do
      expect(cookie_route("foo=bar") do
        cookies.clear
        response['Set-Cookie']
      end).to include("foo=;", "expires=", "1970 00:00:00")
    end
  end

  describe :compare_by_identity? do
    it { expect(cookies).not_to be_compare_by_identity }
  end

  describe :default do
    it { expect(cookies.default).to be_nil }
  end

  describe :default_proc do
    it { expect(cookies.default_proc).to be_nil }
  end

  describe :delete do
    it 'removes request cookies from cookies hash' do
      jar = cookies('foo=bar')
      expect(jar['foo']).to eq('bar')
      jar.delete 'foo'
      expect(jar['foo']).to be_nil
    end

    it 'does not remove response cookies from cookies hash' do
      expect(cookie_route do
        cookies['foo'] = 'bar'
        cookies.delete 'foo'
        cookies['foo']
      end).to eq('bar')
    end

    it 'expires existing cookies' do
      expect(cookie_route("foo=bar") do
        cookies.delete 'foo'
        response['Set-Cookie']
      end).to include("foo=;", "expires=", "1970 00:00:00")
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
      expect(cookie_header).to include("path=/foo;", "domain=bar.com;", "secure;", "httponly")
    end

    it 'does not touch other cookies' do
      expect(cookie_route("foo=bar", "bar=baz") do
        cookies.delete 'foo'
        cookies['bar']
      end).to eq('baz')
    end

    it 'returns the previous value for request cookies' do
      expect(cookie_route("foo=bar") do
        cookies.delete "foo"
      end).to eq("bar")
    end

    it 'returns the previous value for response cookies' do
      expect(cookie_route do
        cookies['foo'] = 'bar'
        cookies.delete "foo"
      end).to eq("bar")
    end

    it 'returns nil for non-existing cookies' do
      expect(cookie_route { cookies.delete("foo") }).to be_nil
    end
  end

  describe :delete_if do
    it 'expires cookies that match the block' do
      expect(cookie_route('foo=bar') do
        cookies['bar'] = 'baz'
        cookies['baz'] = 'foo'
        cookies.delete_if { |*a| a.include? 'bar' }
        response['Set-Cookie']
      end).to eq(["bar=baz; domain=example.org; path=/; httponly",
                  "baz=foo; domain=example.org; path=/; httponly",
                  "foo=; domain=example.org; path=/; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT; httponly",
                  "bar=; domain=example.org; path=/; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT; httponly"])
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

      expect(keys.sort).to eq(['bar', 'foo'])
      expect(foo).to eq('bar')
      expect(bar).to eq('baz')
    end

    it 'favors response over request cookies' do
      seen = false
      key = nil
      value = nil
      cookie_route('foo=bar') do
        cookies[:foo] = 'baz'
        cookies.each do |k,v|
          key = k
          value = v
        end
      end
      expect(key).to eq('foo')
      expect(value).to eq('baz')
      expect(seen).to eq(false)
    end

    it 'does not loop through deleted cookies' do
      cookie_route('foo=bar') do
        cookies.delete :foo
        cookies.each { fail }
      end
    end

    it 'returns an enumerator' do
      keys = []
      cookie_route('foo=bar') do
        enum = cookies.each
        enum.each { |key, value| keys << key }
      end
      keys.each{ |key| expect(key).to eq('foo')}
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

      expect(keys.sort).to eq(['bar', 'foo'])
    end

    it 'only yields keys once' do
      seen = false
      cookie_route('foo=bar') do
        cookies[:foo] = 'baz'
      end
      expect(seen).to eq(false)
    end

    it 'does not loop through deleted cookies' do
      cookie_route('foo=bar') do
        cookies.delete :foo
        cookies.each_key { fail }
      end
    end

    it 'returns an enumerator' do
      keys = []
      cookie_route('foo=bar') do
        enum = cookies.each_key
        enum.each { |key|  keys << key }
      end
      keys.each{ |key| expect(key).to eq('foo')}
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

      expect(keys.sort).to eq(['bar', 'foo'])
      expect(foo).to eq('bar')
      expect(bar).to eq('baz')
    end

    it 'favors response over request cookies' do
      seen = false
      key = nil
      value = nil
      cookie_route('foo=bar') do
        cookies[:foo] = 'baz'
        cookies.each_pair do |k, v|
          key = k
          value = v
        end
      end
      expect(key).to eq('foo')
      expect(value).to eq('baz')
      expect(seen).to eq(false)
    end

    it 'does not loop through deleted cookies' do
      cookie_route('foo=bar') do
        cookies.delete :foo
        cookies.each_pair { fail }
      end
    end

    it 'returns an enumerator' do
      keys = []
      cookie_route('foo=bar') do
        enum = cookies.each_pair
        enum.each { |key, value| keys << key }
      end
      keys.each{ |key| expect(key).to eq('foo')}
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

      expect(values.sort).to eq(['bar', 'baz'])
    end

    it 'favors response over request cookies' do
      value = nil
      cookie_route('foo=bar') do
        cookies[:foo] = 'baz'
        cookies.each_value do |v|
          value = v
        end
      end
      expect(value).to eq('baz')
    end

    it 'does not loop through deleted cookies' do
      cookie_route('foo=bar') do
        cookies.delete :foo
        cookies.each_value { fail }
      end
    end

    it 'returns an enumerator' do
      enum = nil
      cookie_route('foo=bar') do
        enum = cookies.each_value
      end
      enum.each { |value| expect(value).to eq('bar') }
    end
  end

  describe :empty? do
    it 'returns true if there are no cookies' do
      expect(cookies).to be_empty
    end

    it 'returns false if there are request cookies' do
      expect(cookies('foo=bar')).not_to be_empty
    end

    it 'returns false if there are response cookies' do
      expect(cookie_route do
        cookies['foo'] = 'bar'
        cookies.empty?
      end).to be false
    end

    it 'does not become true if response cookies are removed' do
      expect(cookie_route do
        cookies['foo'] = 'bar'
        cookies.delete :foo
        cookies.empty?
      end).to be false
    end

    it 'becomes true if request cookies are removed' do
      expect(cookie_route('foo=bar') do
        cookies.delete :foo
        cookies.empty?
      end).to be_truthy
    end

    it 'does not become true after clear' do
      expect(cookie_route('foo=bar', 'bar=baz') do
        cookies['foo'] = 'bar'
        cookies.clear
        cookies.empty?
      end).to be false
    end
  end

  describe :fetch do
    it 'returns values from request cookies' do
      expect(cookies('foo=bar').fetch('foo')).to eq('bar')
    end

    it 'returns values from response cookies' do
      expect(cookie_route do
        cookies['foo'] = 'bar'
        cookies.fetch('foo')
      end).to eq('bar')
    end

    it 'favors response over request cookies' do
      expect(cookie_route('foo=baz') do
        cookies['foo'] = 'bar'
        cookies.fetch('foo')
      end).to eq('bar')
    end

    it 'raises an exception if key does not exist' do
      error = if defined? JRUBY_VERSION
        IndexError
      else
        KeyError
      end
      expect { cookies.fetch('foo') }.to raise_exception(error)
    end

    it 'returns the block result if missing' do
      expect(cookies.fetch('foo') { 'bar' }).to eq('bar')
    end
  end

  describe :flatten do
    it { expect(cookies('foo=bar').flatten).to eq({'foo' => 'bar'}.flatten) }
  end if Hash.method_defined? :flatten

  describe :has_key? do
    it 'checks request cookies' do
      expect(cookies('foo=bar')).to have_key('foo')
    end

    it 'checks response cookies' do
      jar = cookies
      jar['foo'] = 'bar'
      expect(jar).to have_key(:foo)
    end

    it 'does not use deleted cookies' do
      jar = cookies('foo=bar')
      jar.delete :foo
      expect(jar).not_to have_key('foo')
    end
  end

  describe :has_value? do
    it 'checks request cookies' do
      expect(cookies('foo=bar')).to have_value('bar')
    end

    it 'checks response cookies' do
      jar = cookies
      jar[:foo] = 'bar'
      expect(jar).to have_value('bar')
    end

    it 'does not use deleted cookies' do
      jar = cookies('foo=bar')
      jar.delete :foo
      expect(jar).not_to have_value('bar')
    end
  end

  describe :include? do
    it 'checks request cookies' do
      expect(cookies('foo=bar')).to include('foo')
    end

    it 'checks response cookies' do
      jar = cookies
      jar['foo'] = 'bar'
      expect(jar).to include(:foo)
    end

    it 'does not use deleted cookies' do
      jar = cookies('foo=bar')
      jar.delete :foo
      expect(jar).not_to include('foo')
    end
  end

  describe :keep_if do
    it 'removes entries' do
      jar = cookies('foo=bar', 'bar=baz')
      jar.keep_if { |*args| args == ['bar', 'baz'] }
      expect(jar).to eq({'bar' => 'baz'})
    end
  end

  describe :key do
    it 'checks request cookies' do
      expect(cookies('foo=bar').key('bar')).to eq('foo')
    end

    it 'checks response cookies' do
      jar = cookies
      jar['foo'] = 'bar'
      expect(jar.key('bar')).to eq('foo')
    end

    it 'returns nil when missing' do
      expect(cookies('foo=bar').key('baz')).to be_nil
    end
  end

  describe :key? do
    it 'checks request cookies' do
      expect(cookies('foo=bar').key?('foo')).to be true
    end

    it 'checks response cookies' do
      jar = cookies
      jar['foo'] = 'bar'
      expect(jar.key?(:foo)).to be true
    end

    it 'does not use deleted cookies' do
      jar = cookies('foo=bar')
      jar.delete :foo
      expect(jar.key?('foo')).to be false
    end
  end

  describe :keys do
    it { expect(cookies('foo=bar').keys).to eq(['foo']) }
  end

  describe :length do
    it { expect(cookies.length).to eq(0) }
    it { expect(cookies('foo=bar').length).to eq(1) }
  end

  describe :member? do
    it 'checks request cookies' do
      expect(cookies('foo=bar').member?('foo')).to be true
    end

    it 'checks response cookies' do
      jar = cookies
      jar['foo'] = 'bar'
      expect(jar.member?(:foo)).to be true
    end

    it 'does not use deleted cookies' do
      jar = cookies('foo=bar')
      jar.delete :foo
      expect(jar.member?('foo')).to be false
    end
  end

  describe :merge do
    it 'is mergeable with a hash' do
      expect(cookies('foo=bar').merge(:bar => :baz)).to eq({"foo" => "bar", :bar => :baz})
    end

    it 'does not create cookies' do
      jar = cookies('foo=bar')
      jar.merge(:bar => 'baz')
      expect(jar).not_to include(:bar)
    end

    it 'takes a block for conflict resolution' do
      update = {'foo' => 'baz', 'bar' => 'baz'}
      merged = cookies('foo=bar').merge(update) do |key, old, other|
        expect(key).to   eq('foo')
        expect(old).to   eq('bar')
        expect(other).to eq('baz')
        'foo'
      end
      expect(merged['foo']).to eq('foo')
    end
  end

  describe :merge! do
    it 'creates cookies' do
      jar = cookies('foo=bar')
      jar.merge! :bar => 'baz'
      expect(jar).to include('bar')
    end

    it 'overrides existing values' do
      jar = cookies('foo=bar')
      jar.merge! :foo => "baz"
      expect(jar["foo"]).to eq("baz")
    end

    it 'takes a block for conflict resolution' do
      update = {'foo' => 'baz', 'bar' => 'baz'}
      jar    = cookies('foo=bar')
      jar.merge!(update) do |key, old, other|
        expect(key).to   eq('foo')
        expect(old).to   eq('bar')
        expect(other).to eq('baz')
        'foo'
      end
      expect(jar['foo']).to eq('foo')
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
      expect(sub).to eq({'foo' => 'bar'})
      expect(jar['bar']).to eq('baz')
    end
  end

  describe :reject! do
    it 'removes entries' do
      jar = cookies('foo=bar', 'bar=baz')
      jar.reject! { |*args| args == ['bar', 'baz'] }
      expect(jar).to eq({'foo' => 'bar'})
    end
  end

  describe :replace do
    it 'replaces entries' do
      jar = cookies('foo=bar', 'bar=baz')
      jar.replace 'foo' => 'baz', 'baz' => 'bar'
      expect(jar).to eq({'foo' => 'baz', 'baz' => 'bar'})
    end
  end

  describe :set do
    it 'sets a cookie' do
      cookie_route { cookies.set('foo', value: 'bar') }
      expect(cookie_jar['foo']).to eq('bar')
    end

    it 'sets a cookie with httponly' do
      expect(cookie_route do
        request.script_name = '/foo'
        cookies.set('foo', value: 'bar', httponly: true)
        response['Set-Cookie'].lines.detect { |l| l.start_with? 'foo=' }
      end).to include('httponly')
    end

    it 'sets a cookie without httponly' do
      expect(cookie_route do
        request.script_name = '/foo'
        cookies.set('foo', value: 'bar', httponly: false)
        response['Set-Cookie'].lines.detect { |l| l.start_with? 'foo=' }
      end).not_to include('httponly')
    end
  end

  describe :select do
    it 'removes entries from new hash' do
      jar = cookies('foo=bar', 'bar=baz')
      sub = jar.select { |*args| args != ['bar', 'baz'] }
      expect(sub).to eq({'foo' => 'bar'}.select { true })
      expect(jar['bar']).to eq('baz')
    end
  end

  describe :select! do
    it 'removes entries' do
      jar = cookies('foo=bar', 'bar=baz')
      jar.select! { |*args| args != ['bar', 'baz'] }
      expect(jar).to eq({'foo' => 'bar'})
    end
  end if Hash.method_defined? :select!

  describe :shift do
    it 'removes from the hash' do
      jar = cookies('foo=bar')
      expect(jar.shift).to eq(['foo', 'bar'])
      expect(jar).not_to include('bar')
    end
  end

  describe :size do
    it { expect(cookies.size).to eq(0) }
    it { expect(cookies('foo=bar').size).to eq(1) }
  end

  describe :update do
    it 'creates cookies' do
      jar = cookies('foo=bar')
      jar.update :bar => 'baz'
      expect(jar).to include('bar')
    end

    it 'overrides existing values' do
      jar = cookies('foo=bar')
      jar.update :foo => "baz"
      expect(jar["foo"]).to eq("baz")
    end

    it 'takes a block for conflict resolution' do
      merge = {'foo' => 'baz', 'bar' => 'baz'}
      jar   = cookies('foo=bar')
      jar.update(merge) do |key, old, other|
        expect(key).to   eq('foo')
        expect(old).to   eq('bar')
        expect(other).to eq('baz')
        'foo'
      end
      expect(jar['foo']).to eq('foo')
    end
  end

  describe :value? do
    it 'checks request cookies' do
      expect(cookies('foo=bar').value?('bar')).to be true
    end

    it 'checks response cookies' do
      jar = cookies
      jar[:foo] = 'bar'
      expect(jar.value?('bar')).to be true
    end

    it 'does not use deleted cookies' do
      jar = cookies('foo=bar')
      jar.delete :foo
      expect(jar.value?('bar')).to be false
    end
  end

  describe :values do
    it { expect(cookies('foo=bar', 'bar=baz').values.sort).to eq(['bar', 'baz']) }
  end

  describe :values_at do
    it { expect(cookies('foo=bar', 'bar=baz').values_at('foo')).to eq(['bar']) }
  end
end
