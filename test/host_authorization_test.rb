# frozen_string_literal: true

require_relative "test_helper"

class HostAuthorization < Minitest::Test
  def assert_response(outcome:, headers:, response:)
    fail_message = "Expected outcome '#{outcome}' for headers '#{headers}'"

    case outcome
    when :allowed
      assert_equal 200, response.status, fail_message
      assert_equal "OK", response.body, fail_message
    when :stopped
      assert_equal 403, response.status, fail_message
      assert_equal "Host not permitted", response.body, fail_message
    end
  end

  allowed_host = "example.com"
  bad_host = "evil.com"
  test_cases = [
    # good requests
    [:allowed, { "HTTP_HOST" => allowed_host }],
    [:allowed, { "HTTP_X_FORWARDED_HOST" => allowed_host }],
    [:allowed, { "HTTP_FORWARDED" => "host=#{allowed_host}" }],

    # bad requests
    [:stopped, { "HTTP_HOST" => bad_host }],
    [:stopped, { "HTTP_X_FORWARDED_HOST" => bad_host }],
    [:stopped, { "HTTP_FORWARDED" => "host=#{bad_host}" }],
    [:stopped, { "HTTP_HOST" => allowed_host, "HTTP_X_FORWARDED_HOST" => bad_host }],
    [:stopped, { "HTTP_HOST" => allowed_host, "HTTP_FORWARDED" => "host=#{bad_host}" }],
  ]

  test_cases.each do |outcome, headers|
    it "allows/stops requests based on the permitted hosts specified" do
      mock_app do
        set :permitted_hosts, [allowed_host]

        get("/") { "OK" }
      end

      request = Rack::MockRequest.new(@app)
      response = request.get("/", headers)

      assert_response(outcome: outcome, headers: headers, response: response)
    end
  end

  it "allows any requests when no permitted hosts are specified" do
    test_cases.each do |_outcome, headers|
      mock_app do
        set :permitted_hosts, []

        get("/") { "OK" }
      end

      fail_message = "Expected request with headers '#{headers}' to be allowed"
      request = Rack::MockRequest.new(@app)
      response = request.get("/", headers)

      assert_equal 200, response.status, fail_message
      assert_equal "OK", response.body, fail_message
    end
  end
end
