# frozen_string_literal: true

require_relative "test_helper"

class HostAuthorization < Minitest::Test
  describe "in development environment" do
    setup do
      Sinatra::Base.set :environment, :development
    end

    %w[
      127.0.0.1
      127.0.0.1:3000
      [::1]
      [::1]:3000
      localhost
      localhost:3000
      foo.localhost
      foo.test
    ].each do |development_host|
      it "allows a host like '#{development_host}'" do
        mock_app do
          get("/") { "OK" }
        end

        headers = { "HTTP_HOST" => development_host }
        request = Rack::MockRequest.new(@app)
        response = request.get("/", headers)

        assert_equal 200, response.status
        assert_equal "OK", response.body
      end
    end

    it "stops non-development hosts by default" do
      mock_app { get("/") { "OK" } }

      get "/", { "HTTP_HOST" => "example.com" }

      assert_equal 403, response.status
      assert_equal "Host not permitted", body
    end

    it "allows any requests when no permitted hosts are specified" do
      mock_app do
        set :host_authorization, { permitted_hosts: [] }
        get("/") { "OK" }
      end

      get "/", { "HTTP_HOST" => "example.com" }

      assert_equal 200, response.status
      assert_equal "OK", body
    end
  end

  describe "in non-development environments" do
    it "allows requests based on the permitted hosts specified" do
      allowed_host = "allowed.org"
      mock_app do
        set :host_authorization, { permitted_hosts: [allowed_host] }

        get("/") { "OK" }
      end

      headers = { "HTTP_HOST" => allowed_host }
      request = Rack::MockRequest.new(@app)
      response = request.get("/", headers)

      assert_equal 200, response.status
      assert_equal "OK", response.body
    end

    it "stops requests based on the permitted hosts specified" do
      allowed_host = "allowed.org"
      mock_app do
        set :host_authorization, { permitted_hosts: [allowed_host] }

        get("/") { "OK" }
      end

      headers = { "HTTP_HOST" => "bad-host.org" }
      request = Rack::MockRequest.new(@app)
      response = request.get("/", headers)

      assert_equal 403, response.status
      assert_equal "Host not permitted", response.body
    end

    it "defaults to permit any hosts" do
      mock_app do
        get("/") { "OK" }
      end

      headers = { "HTTP_HOST" => "some-host.org" }
      request = Rack::MockRequest.new(@app)
      response = request.get("/", headers)

      assert_equal 200, response.status
      assert_equal "OK", response.body
    end

    it "stops the request using the configured response" do
      allowed_host = "allowed.org"
      status = 418
      message = "No coffee for you"
      mock_app do
        set :host_authorization, {
          permitted_hosts: [allowed_host],
          status: status,
          message: message,
        }

        get("/") { "OK" }
      end

      headers = { "HTTP_HOST" => "bad-host.org" }
      request = Rack::MockRequest.new(@app)
      response = request.get("/", headers)

      assert_equal status, response.status
      assert_equal message, response.body
    end

    it "allows custom logic with 'allow_if'" do
      allowed_host = "allowed.org"
      mock_app do
        set :host_authorization, {
          permitted_hosts: [allowed_host],
          allow_if: ->(env) do
            request = Sinatra::Request.new(env)
            request.path == "/allowed"
          end
        }

        get("/") { "OK" }
        get("/allowed") { "OK" }
      end

      headers = { "HTTP_HOST" => "some-host.org" }
      request = Rack::MockRequest.new(@app)
      response = request.get("/allowed", headers)
      assert_equal 200, response.status
      assert_equal "OK", response.body

      request = Rack::MockRequest.new(@app)
      response = request.get("/", headers)
      assert_equal 403, response.status
    end
  end
end
