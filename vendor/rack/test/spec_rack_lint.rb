require 'test/spec'
require 'stringio'

require 'rack/lint'
require 'rack/mock'

context "Rack::Lint" do
  def env(*args)
    Rack::MockRequest.env_for("/", *args)
  end
  
  specify "passes valid request" do
    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, {"Content-type" => "test/plain"}, "foo"]
                     }).call(env({}))
    }.should.not.raise
  end

  specify "notices fatal errors" do
    lambda { Rack::Lint.new(nil).call }.should.raise(Rack::Lint::LintError).
      message.should.match(/No env given/)
  end

  specify "notices environment errors" do
    lambda { Rack::Lint.new(nil).call 5 }.should.raise(Rack::Lint::LintError).
      message.should.match(/not a Hash/)

    lambda {
      e = env
      e.delete("REQUEST_METHOD")
      Rack::Lint.new(nil).call(e)
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/missing required key REQUEST_METHOD/)

    lambda {
      e = env
      e.delete("SERVER_NAME")
      Rack::Lint.new(nil).call(e)
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/missing required key SERVER_NAME/)


    lambda {
      Rack::Lint.new(nil).call(env("HTTP_CONTENT_TYPE" => "text/plain"))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/contains HTTP_CONTENT_TYPE/)

    lambda {
      Rack::Lint.new(nil).call(env("HTTP_CONTENT_LENGTH" => "42"))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/contains HTTP_CONTENT_LENGTH/)

    lambda {
      Rack::Lint.new(nil).call(env("FOO" => Object.new))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/non-string value/)

    lambda {
      Rack::Lint.new(nil).call(env("rack.version" => "0.2"))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/must be an Array/)

    lambda {
      Rack::Lint.new(nil).call(env("rack.url_scheme" => "gopher"))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/url_scheme unknown/)

    lambda {
      Rack::Lint.new(nil).call(env("REQUEST_METHOD" => "FUCKUP"))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/REQUEST_METHOD unknown/)

    lambda {
      Rack::Lint.new(nil).call(env("SCRIPT_NAME" => "howdy"))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/must start with/)

    lambda {
      Rack::Lint.new(nil).call(env("PATH_INFO" => "../foo"))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/must start with/)

    lambda {
      Rack::Lint.new(nil).call(env("CONTENT_LENGTH" => "xcii"))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/Invalid CONTENT_LENGTH/)

    lambda {
      e = env
      e.delete("PATH_INFO")
      e.delete("SCRIPT_NAME")
      Rack::Lint.new(nil).call(e)
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/One of .* must be set/)

    lambda {
      Rack::Lint.new(nil).call(env("SCRIPT_NAME" => "/"))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/cannot be .* make it ''/)
  end

  specify "notices input errors" do
    lambda {
      Rack::Lint.new(nil).call(env("rack.input" => ""))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/does not respond to #gets/)
  end

  specify "notices error errors" do
    lambda {
      Rack::Lint.new(nil).call(env("rack.errors" => ""))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/does not respond to #puts/)
  end

  specify "notices status errors" do
    lambda {
      Rack::Lint.new(lambda { |env|
                       ["cc", {}, ""]
                     }).call(env({}))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/must be >100 seen as integer/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       [42, {}, ""]
                     }).call(env({}))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/must be >100 seen as integer/)
  end

  specify "notices header errors" do
    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, Object.new, ""]
                     }).call(env({}))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/should respond to #each/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, {true=>false}, ""]
                     }).call(env({}))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/header key must be a string/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, {"Status" => "404"}, ""]
                     }).call(env({}))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/must not contain Status/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, {"Content-Type:" => "text/plain"}, ""]
                     }).call(env({}))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/must not contain :/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, {"Content-" => "text/plain"}, ""]
                     }).call(env({}))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/must not end/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, {"..%%quark%%.." => "text/plain"}, ""]
                     }).call(env({}))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/invalid header/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, {"Foo" => Object.new}, ""]
                     }).call(env({}))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/must respond to #each/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, {"Foo" => [1,2,3]}, ""]
                     }).call(env({}))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/must consist of Strings/)


    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, {"Foo-Bar" => "text\000plain"}, ""]
                     }).call(env({}))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/invalid header/)
  end

  specify "notices content-type errors" do
    lambda {
      Rack::Lint.new(lambda { |env|
                       [200, {}, ""]
                     }).call(env({}))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/No Content-Type/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       [204, {"Content-Type" => "text/plain"}, ""]
                     }).call(env({}))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/Content-Type header found/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       [204, {"Content-type" => "text/plain"}, ""]
                     }).call(env({}))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/Content-Type header found/)
  end

  specify "notices body errors" do
    lambda {
      status, header, body = Rack::Lint.new(lambda { |env|
                               [200, {"Content-type" => "text/plain"}, [1,2,3]]
                             }).call(env({}))
      body.each { |part| }
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/yielded non-string/)
  end

  specify "notices input handling errors" do
    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].gets("\r\n")
                       [201, {"Content-type" => "text/plain"}, ""]
                     }).call(env({}))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/gets called with arguments/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].read("foo")
                       [201, {"Content-type" => "text/plain"}, ""]
                     }).call(env({}))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/read called with non-integer argument/)

    weirdio = Object.new
    class << weirdio
      def gets
        42
      end

      def read
        23
      end

      def each
        yield 23
        yield 42
      end
    end

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].gets
                       [201, {"Content-type" => "text/plain"}, ""]
                     }).call(env("rack.input" => weirdio))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/gets didn't return a String/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].each { |x| }
                       [201, {"Content-type" => "text/plain"}, ""]
                     }).call(env("rack.input" => weirdio))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/each didn't yield a String/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].read
                       [201, {"Content-type" => "text/plain"}, ""]
                     }).call(env("rack.input" => weirdio))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/read didn't return a String/)


    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.input"].close
                       [201, {"Content-type" => "text/plain"}, ""]
                     }).call(env({}))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/close must not be called/)
  end

  specify "notices error handling errors" do
    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.errors"].write(42)
                       [201, {"Content-type" => "text/plain"}, ""]
                     }).call(env({}))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/write not called with a String/)

    lambda {
      Rack::Lint.new(lambda { |env|
                       env["rack.errors"].close
                       [201, {"Content-type" => "text/plain"}, ""]
                     }).call(env({}))
    }.should.raise(Rack::Lint::LintError).
      message.should.match(/close must not be called/)
  end

end
