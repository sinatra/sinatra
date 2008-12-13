module Rack
  class MethodOverride
    HTTP_METHODS = %w(GET HEAD PUT POST DELETE OPTIONS)

    def initialize(app)
      @app = app
    end

    def call(env)
      if env["REQUEST_METHOD"] == "POST"
        req = Request.new(env)
        method = req.POST["_method"].to_s.upcase
        if HTTP_METHODS.include?(method)
          env["REQUEST_METHOD"] = method
        end
      end

      @app.call(env)
    end
  end
end
