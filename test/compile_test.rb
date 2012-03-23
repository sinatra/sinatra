# I like coding: UTF-8
require File.expand_path('../helper', __FILE__)

class CompileTest < Test::Unit::TestCase
  #  Pattern, Current Regexp, [Examples, Should Bes]
  #
  [
    ["/", %r{\A/\z}, [
      ["/", []]
    ]], 
    ["/foo", %r{\A/foo\z}, [
      ["/foo", []]
    ]], 
    ["/:foo", %r{\A/([^/?#]+)\z}, [
      ["/foo"      , ["foo"]],
      ["/foo?"     , nil],
      ["/foo/bar"  , nil],
      ["/foo%2Fbar", ["foo%2Fbar"]],
      ["/"         , nil],
      ["/foo/"     , nil]
    ]],
    ["/f\u00F6\u00F6", %r{\A/f%C3%B6%C3%B6\z}, [
      ["/f%C3%B6%C3%B6", []]
    ]], 
    ["/:foo/:bar", %r{\A/([^/?#]+)/([^/?#]+)\z}, [
      ["/foo/bar", ["foo", "bar"]]
    ]], 
    ["/hello/:person", %r{\A/hello/([^/?#]+)\z}, [
      ["/hello/Frank", ["Frank"]]
    ]], 
    ["/?:foo?/?:bar?", %r{\A/?([^/?#]+)?/?([^/?#]+)?\z}, [
      ["/hello/world", ["hello", "world"]],
      ["/hello"      , ["hello", nil]],
      ["/"           , [nil, nil]],
      [""            , [nil, nil]]
    ]], 
    ["/*", %r{\A/(.*?)\z}, [
      ["/"       , [""]],
      ["/foo"    , ["foo"]],
      ["/"       , [""]],
      ["/foo/bar", ["foo/bar"]]
    ]], 
    ["/:foo/*", %r{\A/([^/?#]+)/(.*?)\z}, [
      ["/foo/bar/baz", ["foo", "bar/baz"]]
    ]],
    ["/:foo/:bar", %r{\A/([^/?#]+)/([^/?#]+)\z}, [
      ["/user@example.com/name", ["user@example.com", "name"]]
    ]], 
    ["/test$/", %r{\A/test(?:\$|%24)/\z}, [
      ["/test$/", []]
    ]], 
    ["/te+st/", %r{\A/te(?:\+|%2B)st/\z}, [
      ["/te+st/",  []],
      ["/test/",   nil],
      ["/teeest/", nil]
    ]],
    ["/test(bar)/", %r{\A/test(?:\(|%28)bar(?:\)|%29)/\z}, [
      ["/test(bar)/", []]
    ]],
    ["/path with spaces", %r{\A/path(?:%20|(?:\+|%2B))with(?:%20|(?:\+|%2B))spaces\z}, [
      ["/path%20with%20spaces", []],
      ["/path%2Bwith%2Bspaces", []],
      ["/path+with+spaces",     []]
    ]],
    ["/foo&bar", %r{\A/foo(?:&|%26)bar\z}, [
      ["/foo&bar", []]
    ]], 
    ["/:foo/*", %r{\A/([^/?#]+)/(.*?)\z}, [
      ["/hello%20world/how%20are%20you", ["hello%20world", "how%20are%20you"]]
    ]], 
    ["/*/foo/*/*", %r{\A/(.*?)/foo/(.*?)/(.*?)\z}, [
      ["/bar/foo/bling/baz/boom", ["bar", "bling", "baz/boom"]],
      ["/bar/foo/baz",            nil],
    ]],
    ["/test.bar", %r{\A/test(?:\.|%2E)bar\z}, [
      ["/test.bar", []],
      ["/test0bar", nil]
    ]],
    ["/:file.:ext", %r{\A/([^\.%2E/?#]+)(?:\.|%2E)([^\.%2E/?#]+)\z}, [
      ["/pony.jpg",   ["pony", "jpg"]],
      ["/pony%2Ejpg", ["pony", "jpg"]],
      ["/.jpg",       nil]
    ]],
    ["/:name.?:format?", %r{\A/([^\.%2E/?#]+)(?:\.|%2E)?([^\.%2E/?#]+)?\z}, [
      ["/foo",       ["foo", nil]],
      ["/.bar",      [".bar", nil]],
      ["/foo.bar",   ["foo", "bar"]],
      ["/foo%2Ebar", ["foo", "bar"]]
    ]], 
    ["/:user@?:host?", %r{\A/([^@%40/?#]+)(?:@|%40)?([^@%40/?#]+)?\z}, [
      ["/foo@bar",     ["foo", "bar"]],
      ["/foo.foo@bar", ["foo.foo", "bar"]],
      ["/foo@bar.bar", ["foo", "bar.bar"]]
    ]]
  ].each do |pattern, regexp, examples_expectations|
    app = nil
    examples_expectations.each do |example, expected|
      it "generates #{regexp.source} from #{pattern}, with #{example} succeeding" do
        app ||= mock_app {}
        compiled, keys = app.send(:compile, pattern)
        match = compiled.match(example)
        match ? assert_equal(expected, match.captures.to_a) : assert_equal(expected, match)
      end
    end
    it "generates #{regexp.source} from #{pattern}" do
      app ||= mock_app {}
      compiled, keys = app.send(:compile, pattern)
      assert_equal regexp, compiled
    end
  end
end
