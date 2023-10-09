require_relative 'test_helper'

class CompileTest < Minitest::Test
  def self.parses pattern, example, expected_params, mtype = :sinatra, mopts = {}
    it "parses #{example} with #{pattern} into params #{expected_params}" do
      compiled = mock_app { set :mustermann_opts, :type => mtype }.send(:compile, pattern, mopts)
      params = compiled.params(example)
      fail %Q{"#{example}" does not parse on pattern "#{pattern}".} unless params

      assert_equal expected_params, params, "Pattern #{pattern} does not match path #{example}."
    end
  end

  def self.fails pattern, example, mtype = :sinatra, mopts = {}
    it "does not parse #{example} with #{pattern}" do
      compiled = mock_app { set :mustermann_opts, :type => mtype }.send(:compile, pattern, mopts)
      match = compiled.match(example)
      fail %Q{"#{pattern}" does parse "#{example}" but it should fail} if match
    end
  end

  def self.raises pattern, mtype = :sinatra, mopts = {}
    it "does not compile #{pattern}" do
      assert_raises(Mustermann::CompileError, %Q{Pattern "#{pattern}" compiles but it should not}) do
        mock_app { set :mustermann_opts, :type => mtype }.send(:compile, pattern, mopts)
      end
    end
  end

  parses "/", "/", {}

  parses "/foo", "/foo", {}

  parses "/:foo", "/foo",       "foo" => "foo"
  parses "/:foo", "/foo.bar",   "foo" => "foo.bar"
  parses "/:foo", "/foo%2Fbar", "foo" => "foo/bar"
  parses "/:foo", "/%0Afoo",    "foo" => "\nfoo"
  fails  "/:foo", "/foo?"
  fails  "/:foo", "/foo/bar"
  fails  "/:foo", "/"
  fails  "/:foo", "/foo/"

  parses "/föö", "/f%C3%B6%C3%B6", {}

  parses "/:foo/:bar", "/foo/bar", "foo" => "foo", "bar" => "bar"

  parses "/hello/:person", "/hello/Frank", "person" => "Frank"

  parses "/?:foo?/?:bar?", "/hello/world", "foo" => "hello", "bar" => "world"
  parses "/?:foo?/?:bar?", "/hello",       "foo" => "hello", "bar" => nil
  parses "/?:foo?/?:bar?", "/",            "foo" => nil, "bar" => nil
  parses "/?:foo?/?:bar?", "",             "foo" => nil, "bar" => nil

  parses "/*", "/",       "splat" => [""]
  parses "/*", "/foo",    "splat" => ["foo"]
  parses "/*", "/foo/bar", "splat" => ["foo/bar"]

  parses "/:foo/*", "/foo/bar/baz", "foo" => "foo", "splat" => ["bar/baz"]

  parses "/:foo/:bar", "/user@example.com/name", "foo" => "user@example.com", "bar" => "name"

  parses "/test$/", "/test$/", {}

  parses "/te+st/", "/te+st/", {}
  fails  "/te+st/", "/test/"
  fails  "/te+st/", "/teeest/"

  parses "/test(bar)/", "/testbar/", {}

  parses "/path with spaces", "/path%20with%20spaces", {}
  parses "/path with spaces", "/path%2Bwith%2Bspaces", {}
  parses "/path with spaces", "/path+with+spaces",     {}

  parses "/foo&bar", "/foo&bar", {}

  parses "/:foo/*", "/hello%20world/how%20are%20you", "foo" => "hello world", "splat" => ["how are you"]

  parses "/*/foo/*/*", "/bar/foo/bling/baz/boom", "splat" => ["bar", "bling", "baz/boom"]
  parses "/*/foo/*/*rest", "/bar/foo/bling/baz/boom", "splat" => ["bar", "bling"], "rest" => "baz/boom"
  fails  "/*/foo/*/*", "/bar/foo/baz"

  parses "/test.bar", "/test.bar", {}
  fails  "/test.bar", "/test0bar"

  parses "/:file.:ext", "/pony.jpg",   "file" => "pony", "ext" => "jpg"
  parses "/:file.:ext", "/pony%2Ejpg", "file" => "pony", "ext" => "jpg"
  fails  "/:file.:ext", "/.jpg"

  parses "/:name.?:format?", "/foo",       "name" => "foo", "format" => nil
  parses "/:name.?:format?", "/foo.bar",   "name" => "foo", "format" => "bar"
  parses "/:name.?:format?", "/foo%2Ebar", "name" => "foo", "format" => "bar"

  parses "/:user@?:host?", "/foo@bar",     "user" => "foo", "host" => "bar"
  parses "/:user@?:host?", "/foo.foo@bar", "user" => "foo.foo", "host" => "bar"
  parses "/:user@?:host?", "/foo@bar.bar", "user" => "foo", "host" => "bar.bar"

  # From https://gist.github.com/2154980#gistcomment-169469.
  #
  parses "/:name(.:format)?", "/foo", "name" => "foo", "format" => nil
  parses "/:name(.:format)?", "/foo.bar", "name" => "foo", "format" => "bar"
  parses "/:name(.:format)?", "/foo.", "name" => "foo.", "format" => nil

  parses "/:id/test.bar", "/3/test.bar", {"id" => "3"}
  parses "/:id/test.bar", "/2/test.bar", {"id" => "2"}
  parses "/:id/test.bar", "/2E/test.bar", {"id" => "2E"}
  parses "/:id/test.bar", "/2e/test.bar", {"id" => "2e"}
  parses "/:id/test.bar", "/%2E/test.bar", {"id" => "."}
  parses "/{id}/test.bar", "/%2E/test.bar", {"id" => "."}

  parses '/10/:id', '/10/test', "id" => "test"
  parses '/10/:id', '/10/te.st', "id" => "te.st"

  parses '/10.1/:id', '/10.1/test', "id" => "test"
  parses '/10.1/:id', '/10.1/te.st', "id" => "te.st"
  parses '/:foo/:id', '/10.1/te.st', "foo" => "10.1", "id" => "te.st"
  parses '/:foo/:id', '/10.1.2/te.st', "foo" => "10.1.2", "id" => "te.st"
  parses '/:foo.:bar/:id', '/10.1/te.st', "foo" => "10", "bar" => "1", "id" => "te.st"

  parses '/:a/:b.?:c?', '/a/b',       "a" => "a",   "b" => "b", "c" => nil
  parses '/:a/:b.?:c?', '/a/b.c',     "a" => "a",   "b" => "b", "c" => "c"
  parses '/:a/:b.?:c?', '/a.b/c',     "a" => "a.b", "b" => "c", "c" => nil
  parses '/:a/:b.?:c?', '/a.b/c.d',   "a" => "a.b", "b" => "c", "c" => "d"
  fails  '/:a/:b.?:c?', '/a.b/c.d/e'

  parses "/:file.:ext", "/pony%2ejpg", "file" => "pony", "ext" => "jpg"
  parses "/:file.:ext", "/pony%E6%AD%A3%2Ejpg", "file" => "pony正", "ext" => "jpg"
  parses "/:file.:ext", "/pony%e6%ad%a3%2ejpg", "file" => "pony正", "ext" => "jpg"
  parses "/:file.:ext", "/pony正%2Ejpg", "file" => "pony正", "ext" => "jpg"
  parses "/:file.:ext", "/pony正%2ejpg", "file" => "pony正", "ext" => "jpg"
  parses "/:file.:ext", "/pony正..jpg", "file" => "pony正.", "ext" => "jpg"

  parses "/:name.:format", "/file.tar.gz", "name" => "file.tar", "format" => "gz"
  parses "/:name.:format1.:format2", "/file.tar.gz", "name" => "file", "format1" => "tar", "format2" => "gz"
  parses "/:name.:format1.:format2", "/file.temp.tar.gz", "name" => "file.temp", "format1" => "tar", "format2" => "gz"

  # From issue #688.
  #
  parses "/articles/10.1103/:doi", "/articles/10.1103/PhysRevLett.110.026401", "doi" => "PhysRevLett.110.026401"

  # Mustermann anchoring
  fails "/bar", "/foo/bar", :regexp
  raises "^/foo/bar$", :regexp
  parses "^/foo/bar$", "/foo/bar", {}, :regexp, :check_anchors => false
end
