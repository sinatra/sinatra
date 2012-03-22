# I like coding: UTF-8
require File.expand_path('../helper', __FILE__)

class CompileTest < Test::Unit::TestCase
  #  Pattern             | Current Regexp                                           | Example     | Should Be
  # ---------------------|----------------------------------------------------------|-------------|----------
  [
    ["/"                 , %r{^/$}                                                   , "/"                              , []                                  ], 
    ["/foo"              , %r{^/foo$}                                                , "/foo"                           , []                                  ], 
    ["/:foo"             , %r{^/([^/?#]+)$}                                          , "/foo"                           , ["foo"]                             ], 
    ["/:foo"             , %r{^/([^/?#]+)$}                                          , "/foo?"                          , nil                                 ], 
    ["/:foo"             , %r{^/([^/?#]+)$}                                          , "/foo/bar"                       , nil                                 ], 
    ["/:foo"             , %r{^/([^/?#]+)$}                                          , "/foo%2Fbar"                     , ["foo%2Fbar"]                       ], 
    ["/:foo"             , %r{^/([^/?#]+)$}                                          , "/"                              , nil                                 ], 
    ["/:foo"             , %r{^/([^/?#]+)$}                                          , "/foo/"                          , nil                                 ], 
    ["/f\u00F6\u00F6"    , %r{^/f%C3%B6%C3%B6$}                                      , "/f%C3%B6%C3%B6"                 , []                                  ], 
    ["/:foo/:bar"        , %r{^/([^/?#]+)/([^/?#]+)$}                                , "/foo/bar"                       , ["foo", "bar"]                      ], 
    ["/hello/:person"    , %r{^/hello/([^/?#]+)$}                                    , "/hello/Frank"                   , ["Frank"]                           ], 
    ["/?:foo?/?:bar?"    , %r{^/?([^/?#]+)?/?([^/?#]+)?$}                            , "/hello/world"                   , ["hello", "world"]                  ], 
    ["/?:foo?/?:bar?"    , %r{^/?([^/?#]+)?/?([^/?#]+)?$}                            , "/hello"                         , ["hello", nil]                      ], 
    ["/?:foo?/?:bar?"    , %r{^/?([^/?#]+)?/?([^/?#]+)?$}                            , "/"                              , [nil, nil]                          ], 
    ["/?:foo?/?:bar?"    , %r{^/?([^/?#]+)?/?([^/?#]+)?$}                            , ""                               , [nil, nil]                          ], 
    ["/*"                , %r{^/(.*?)$}                                              , "/"                              , [""]                                ], 
    ["/*"                , %r{^/(.*?)$}                                              , "/foo"                           , ["foo"]                             ], 
    ["/*"                , %r{^/(.*?)$}                                              , "/"                              , [""]                                ], 
    ["/*"                , %r{^/(.*?)$}                                              , "/foo/bar"                       , ["foo/bar"]                         ], 
    ["/:foo/*"           , %r{^/([^/?#]+)/(.*?)$}                                    , "/foo/bar/baz"                   , ["foo", "bar/baz"]                  ], 
    ["/:foo/:bar"        , %r{^/([^/?#]+)/([^/?#]+)$}                                , "/user@example.com/name"         , ["user@example.com", "name"]        ], 
    ["/:file.:ext"       , %r{^/([^/?#]+)(?:\.|%2E)([^/?#]+)$}                       , "/pony.jpg"                      , ["pony", "jpg"]                     ], 
    ["/:file.:ext"       , %r{^/([^/?#]+)(?:\.|%2E)([^/?#]+)$}                       , "/pony%2Ejpg"                    , ["pony", "jpg"]                     ], 
    ["/:file.:ext"       , %r{^/([^/?#]+)(?:\.|%2E)([^/?#]+)$}                       , "/.jpg"                          , nil                                 ], 
    ["/test.bar"         , %r{^/test(?:\.|%2E)bar$}                                  , "/test.bar"                      , []                                  ], 
    ["/test.bar"         , %r{^/test(?:\.|%2E)bar$}                                  , "/test0bar"                      , nil                                 ], 
    ["/test$/"           , %r{^/test(?:\$|%24)/$}                                    , "/test$/"                        , []                                  ], 
    ["/te+st/"           , %r{^/te(?:\+|%2B)st/$}                                    , "/te+st/"                        , []                                  ], 
    ["/te+st/"           , %r{^/te(?:\+|%2B)st/$}                                    , "/test/"                         , nil                                 ], 
    ["/te+st/"           , %r{^/te(?:\+|%2B)st/$}                                    , "/teeest/"                       , nil                                 ], 
    ["/test(bar)/"       , %r{^/test(?:\(|%28)bar(?:\)|%29)/$}                       , "/test(bar)/"                    , []                                  ], 
    ["/path with spaces" , %r{^/path(?:%20|(?:\+|%2B))with(?:%20|(?:\+|%2B))spaces$} , "/path%20with%20spaces"          , []                                  ], 
    ["/path with spaces" , %r{^/path(?:%20|(?:\+|%2B))with(?:%20|(?:\+|%2B))spaces$} , "/path%2Bwith%2Bspaces"          , []                                  ], 
    ["/path with spaces" , %r{^/path(?:%20|(?:\+|%2B))with(?:%20|(?:\+|%2B))spaces$} , "/path+with+spaces"              , []                                  ], 
    ["/foo&bar"          , %r{^/foo(?:&|%26)bar$}                                    , "/foo&bar"                       , []                                  ], 
    ["/:foo/*"           , %r{^/([^/?#]+)/(.*?)$}                                    , "/hello%20world/how%20are%20you" , ["hello%20world", "how%20are%20you"]], 
    ["/*/foo/*/*"        , %r{^/(.*?)/foo/(.*?)/(.*?)$}                              , "/bar/foo/bling/baz/boom"        , ["bar", "bling", "baz/boom"]        ], 
    ["/*/foo/*/*"        , %r{^/(.*?)/foo/(.*?)/(.*?)$}                              , "/bar/foo/baz"                   , nil                                 ], 
    ["/:name.?:format?"  , %r{^/([^/?#]+)(?:\.|%2E)?([^/?#]+)?$}                     , "/foo"                           , ["foo", nil]                        ], 
    ["/:name.?:format?"  , %r{^/([^/?#]+)(?:\.|%2E)?([^/?#]+)?$}                     , "/.bar"                          , [".bar", nil]                       ],
    ["/:name.?:format?"  , %r{^/([^/?#]+)(?:\.|%2E)?([^/?#]+)?$}                     , "/foo.bar"                       , ["foo", "bar"]                      ], 
    ["/:name.?:format?"  , %r{^/([^/?#]+)(?:\.|%2E)?([^/?#]+)?$}                     , "/foo%2Ebar"                     , ["foo", "bar"]                      ], 
    ["/:user@?:host?"    , %r{^/([^/?#]+)(?:@|%40)?([^/?#]+)?$}                      , "/foo@bar"                       , ["foo", "bar"]                      ],                
    ["/:user@?:host?"    , %r{^/([^/?#]+)(?:@|%40)?([^/?#]+)?$}                      , "/foo.foo@bar"                   , ["foo.foo", "bar"]                  ],                
    ["/:user@?:host?"    , %r{^/([^/?#]+)(?:@|%40)?([^/?#]+)?$}                      , "/foo@bar.bar"                   , ["foo", "bar.bar"]                  ],
  ].each do |pattern, regexp, example, expected|
    app = nil
    it "generates #{regexp.source} from #{pattern}, with #{example} succeeding" do
      app ||= mock_app {}
      compiled, keys = app.send(:compile, pattern)
      assert_equal regexp.source, compiled.source
      match = compiled.match(example)
      match ? assert_equal(expected, match.captures.to_a) : assert_nil(expected)
    end
  end
end
