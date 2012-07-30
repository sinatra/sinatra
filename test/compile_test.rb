# I like coding: UTF-8
require File.expand_path('../helper', __FILE__)

class CompileTest < Test::Unit::TestCase

  def self.converts pattern, expected_regexp
    it "generates #{expected_regexp.source} from #{pattern}" do
      compiled, _ = compiled pattern
      assert_equal expected_regexp, compiled
    end
  end
  def self.parses pattern, example, expected_params
    it "parses #{example} with #{pattern} into params #{expected_params}" do
      compiled, keys = compiled pattern
      match = compiled.match(example)
      fail %Q{"#{example}" does not parse on pattern "#{pattern}".} unless match

      # Aggregate e.g. multiple splat values into one array.
      #
      params = keys.zip(match.captures).reduce({}) do |hash, mapping|
        key, value = mapping
        hash[key] = if existing = hash[key]
          existing.respond_to?(:to_ary) ? existing << value : [existing, value]
        else
          value
        end
        hash
      end

      assert_equal(expected_params, params)
    end
  end
  def self.fails pattern, example
    it "does not parse #{example} with #{pattern}" do
      compiled, _ = compiled pattern
      match = compiled.match(example)
      fail %Q{"#{pattern}" does parse "#{example}" but it should fail} if match
    end
  end
  def compiled pattern
    app ||= mock_app {}
    compiled, keys = app.send(:compile, pattern)
    [compiled, keys]
  end

  converts "/", %r{\A/\z}
  parses "/", "/", {}

  converts "/foo", %r{\A/foo\z}
  parses "/foo", "/foo", {}

  converts "/:foo", %r{\A/([^/?#]+)\z}
  parses "/:foo", "/foo",       "foo" => "foo"
  parses "/:foo", "/foo.bar",   "foo" => "foo.bar"
  parses "/:foo", "/foo%2Fbar", "foo" => "foo%2Fbar"
  fails  "/:foo", "/foo?"
  fails  "/:foo", "/foo/bar"
  fails  "/:foo", "/"
  fails  "/:foo", "/foo/"

  converts "/föö", %r{\A/f%C3%B6%C3%B6\z}
  parses "/föö", "/f%C3%B6%C3%B6", {}

  converts "/:foo/:bar", %r{\A/([^/?#]+)/([^/?#]+)\z}
  parses "/:foo/:bar", "/foo/bar", "foo" => "foo", "bar" => "bar"

  converts "/hello/:person", %r{\A/hello/([^/?#]+)\z}
  parses "/hello/:person", "/hello/Frank", "person" => "Frank"

  converts "/?:foo?/?:bar?", %r{\A/?([^/?#]+)?/?([^/?#]+)?\z}
  parses "/?:foo?/?:bar?", "/hello/world", "foo" => "hello", "bar" => "world"
  parses "/?:foo?/?:bar?", "/hello",       "foo" => "hello", "bar" => nil
  parses "/?:foo?/?:bar?", "/",            "foo" => nil, "bar" => nil
  parses "/?:foo?/?:bar?", "",             "foo" => nil, "bar" => nil

  converts "/*", %r{\A/(.*?)\z}
  parses "/*", "/",       "splat" => ""
  parses "/*", "/foo",    "splat" => "foo"
  parses "/*", "/foo/bar", "splat" => "foo/bar"

  converts "/:foo/*", %r{\A/([^/?#]+)/(.*?)\z}
  parses "/:foo/*", "/foo/bar/baz", "foo" => "foo", "splat" => "bar/baz"

  converts "/:foo/:bar", %r{\A/([^/?#]+)/([^/?#]+)\z}
  parses "/:foo/:bar", "/user@example.com/name", "foo" => "user@example.com", "bar" => "name"

  converts "/test$/", %r{\A/test(?:\$|%24)/\z}
  parses "/test$/", "/test$/", {}

  converts "/te+st/", %r{\A/te(?:\+|%2B)st/\z}
  parses "/te+st/", "/te+st/", {}
  fails  "/te+st/", "/test/"
  fails  "/te+st/", "/teeest/"

  converts "/test(bar)/", %r{\A/test(?:\(|%28)bar(?:\)|%29)/\z}
  parses "/test(bar)/", "/test(bar)/", {}

  converts "/path with spaces", %r{\A/path(?:%20|(?:\+|%2B))with(?:%20|(?:\+|%2B))spaces\z}
  parses "/path with spaces", "/path%20with%20spaces", {}
  parses "/path with spaces", "/path%2Bwith%2Bspaces", {}
  parses "/path with spaces", "/path+with+spaces",     {}

  converts "/foo&bar", %r{\A/foo(?:&|%26)bar\z}
  parses "/foo&bar", "/foo&bar", {}

  converts "/:foo/*", %r{\A/([^/?#]+)/(.*?)\z}
  parses "/:foo/*", "/hello%20world/how%20are%20you", "foo" => "hello%20world", "splat" => "how%20are%20you"

  converts "/*/foo/*/*", %r{\A/(.*?)/foo/(.*?)/(.*?)\z}
  parses "/*/foo/*/*", "/bar/foo/bling/baz/boom", "splat" => ["bar", "bling", "baz/boom"]
  fails  "/*/foo/*/*", "/bar/foo/baz"

  converts "/test.bar", %r{\A/test(?:\.|%2E)bar\z}
  parses "/test.bar", "/test.bar", {}
  fails  "/test.bar", "/test0bar"

  converts "/:file.:ext", %r{\A/([^\.%2E/?#]+)(?:\.|%2E)([^\.%2E/?#]+)\z}
  parses "/:file.:ext", "/pony.jpg",   "file" => "pony", "ext" => "jpg"
  parses "/:file.:ext", "/pony%2Ejpg", "file" => "pony", "ext" => "jpg"
  fails  "/:file.:ext", "/.jpg"

  converts "/:name.?:format?", %r{\A/([^\.%2E/?#]+)(?:\.|%2E)?([^\.%2E/?#]+)?\z}
  parses "/:name.?:format?", "/foo",       "name" => "foo", "format" => nil
  parses "/:name.?:format?", "/foo.bar",   "name" => "foo", "format" => "bar"
  parses "/:name.?:format?", "/foo%2Ebar", "name" => "foo", "format" => "bar"
  fails  "/:name.?:format?", "/.bar"

  converts "/:user@?:host?", %r{\A/([^@%40/?#]+)(?:@|%40)?([^@%40/?#]+)?\z}
  parses "/:user@?:host?", "/foo@bar",     "user" => "foo", "host" => "bar"
  parses "/:user@?:host?", "/foo.foo@bar", "user" => "foo.foo", "host" => "bar"
  parses "/:user@?:host?", "/foo@bar.bar", "user" => "foo", "host" => "bar.bar"

  # From https://gist.github.com/2154980#gistcomment-169469.
  #
  # converts "/:name(.:format)?", %r{\A/([^\.%2E/?#]+)(?:\(|%28)(?:\.|%2E)([^\.%2E/?#]+)(?:\)|%29)?\z}
  # parses "/:name(.:format)?", "/foo", "name" => "foo", "format" => nil
  # parses "/:name(.:format)?", "/foo.bar", "name" => "foo", "format" => "bar"
  fails "/:name(.:format)?", "/foo."
end
