# I like coding: UTF-8
require File.expand_path('../helper', __FILE__)

class CompileTest < Test::Unit::TestCase
  
  def self.parses pattern, example, expected_params
    it "parses #{example} with #{pattern} into params #{expected_params}" do
      app ||= mock_app {}
      compiled, keys = app.send(:compile, pattern)
      match = compiled.match(example)
      fail %Q{"#{example}" does not parse on pattern "#{pattern}".} unless match
      params = Hash[keys.zip(match.captures)]
      assert_equal(expected_params, params)
    end
  end
  def self.fails pattern, example
    it "does not parse #{example} with #{pattern}" do
      app ||= mock_app {}
      compiled, keys = app.send(:compile, pattern)
      match = compiled.match(example)
      fail unless match.nil? || match.captures.empty?
    end
  end
  
  parses "/",    "/",    {}
  parses "/foo", "/foo", {}
  
  parses "/:foo", "/foo",       "foo" => "foo"
  parses "/:foo", "/foo.bar",   "foo" => "foo.bar"
  parses "/:foo", "/foo%2Fbar", "foo" => "foo%2Fbar"
  fails  "/:foo", "/foo?"
  fails  "/:foo", "/foo/bar"
  fails  "/:foo", "/"
  fails  "/:foo", "/foo/"
  
  fails  "/f\u00F6\u00F6", "/f%C3%B6%C3%B6"
  
  parses "/:foo/:bar", "/foo/bar", "foo" => "foo", "bar" => "bar"
  
  parses "/hello/:person", "/hello/Frank", "person" => "Frank"
  
  parses "/?:foo?/?:bar?", "/hello/world", "foo" => "hello", "bar" => "world"
  parses "/?:foo?/?:bar?", "/hello",       "foo" => "hello", "bar" => nil
  parses "/?:foo?/?:bar?", "/",            "foo" => nil, "bar" => nil
  parses "/?:foo?/?:bar?", "",             "foo" => nil, "bar" => nil
  
  parses "/*", "/",       "splat" => ""
  parses "/*", "/foo",    "splat" => "foo"
  parses "/*", "/foo/bar", "splat" => "foo/bar"
  
  parses "/:foo/*", "/foo/bar/baz", "foo" => "foo", "splat" => "bar/baz"
  
  parses "/:foo/:bar", "/user@example.com/name", "foo" => "user@example.com", "bar" => "name"
  
  fails  "/test$/", "/test$/"

  parses "/te+st/", "/te+st/", {}
  fails  "/te+st/", "/test/"
  fails  "/te+st/", "/teeest/"
  
  parses "/test(bar)/", "/test(bar)/", {}
  
  parses "/path with spaces", "/path%20with%20spaces", {}
  parses "/path with spaces", "/path%2Bwith%2Bspaces", {}
  parses "/path with spaces", "/path+with+spaces",     {}
  
  parses "/foo&bar", "/foo&bar", {}
  
  parses "/:foo/*", "/hello%20world/how%20are%20you", "foo" => "hello%20world", "splat" => "how%20are%20you"
  
  parses "/*/foo/*/*", "/bar/foo/bling/baz/boom", "splat" => "baz/boom" # TODO
  fails  "/*/foo/*/*", "/bar/foo/baz"
  
  parses "/test.bar", "/test.bar", {}
  fails  "/test.bar", "/test0bar"
  
  parses "/:file.:ext", "/pony.jpg",   "file" => "pony", "ext" => "jpg"
  parses "/:file.:ext", "/pony%2Ejpg", "file" => "pony", "ext" => "jpg"
  fails  "/:file.:ext", "/.jpg"
  
  parses "/:name.?:format?", "/foo",       "name" => "foo", "format" => nil
  parses "/:name.?:format?", "/foo.bar",   "name" => "foo", "format" => "bar"
  parses "/:name.?:format?", "/foo%2Ebar", "name" => "foo", "format" => "bar"
  fails  "/:name.?:format?", "/.bar"
  
  parses "/:user@?:host?", "/foo@bar",     "user" => "foo", "host" => "bar"
  parses "/:user@?:host?", "/foo.foo@bar", "user" => "foo.foo", "host" => "bar"
  parses "/:user@?:host?", "/foo@bar.bar", "user" => "foo", "host" => "bar.bar"
  
  # From https://gist.github.com/2154980#gistcomment-169469.
  #
  # parses "/:name(.:format)?", "/foo", "name" => "foo", "format" => nil
  # parses "/:name(.:format)?", "/foo.bar", "name" => "foo", "format" => "bar"
end
