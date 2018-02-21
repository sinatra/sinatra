require 'rack/protection'
require 'securerandom'
require 'base64'

module Rack
  module Protection
    ##
    # Prevented attack::   CSRF
    # Supported browsers:: all
    # More infos::         http://en.wikipedia.org/wiki/Cross-site_request_forgery
    #
    # Only accepts unsafe HTTP requests if a given access token matches the token
    # included in the session.
    #
    # Compatible with the {rack-csrf}[https://rubygems.org/gems/rack_csrf] gem.
    #
    # The middleware only accepts unsafe HTTP requests (exclude <tt>GET</tt>,
    # <tt>HEAD</tt>, <tt>OPTIONS</tt>, <tt>TRACE</tt>) if a given access token
    # matches the token included in the session.
    # 
    # It checks either <tt>X-CSRF-Token</tt> header or <tt>POST</tt> form data.
    #
    # == Options
    #
    # [authenticity_param] Defines the name of the param that should contain
    #                      the token on a request.
    #
    # == Example: Using option <tt>authenticity_token</tt>
    #
    # To customize the authenticity parameter for form data (default is <tt>"authenticity_token"</tt>):
    #   use Rack::Protection::AuthenticityToken, authenticity_param: 'your_param_name'
    #
    # == Example: Forms application
    #
    # To show what the AuthenticityToken does, this section includes a sample
    # program which shows two forms. One with, and one without a CSRF token
    # The one without CSRF token field will get a 403 Forbidden response.
    #
    # Install the gem, then run the program:
    #
    #   gem install 'rack-protection'
    #   ruby server.rb
    #
    # Here is <tt>server.rb</tt>:
    #
    #  require 'rack/protection'
    #  csrf_param = 'token'
    #
    #  app = Rack::Builder.app do
    #    use Rack::Session::Cookie, secret: 'secret'
    #    use Rack::Protection::AuthenticityToken, authenticity_param: csrf_param
    #    run -> (env) do
    #      [200, {}, [
    #        <<~EOS
    #          <!DOCTYPE html>
    #          <html lang="en">
    #          <head>
    #            <meta charset="UTF-8">
    #            <title>rack-protection minimal example</title>
    #            <meta content="#{csrf_param}" name="csrf-param" />
    #            <meta content="#{env['rack.session'][:csrf]}" name="csrf-token" />
    #          </head>
    #          <body>
    #            <h1>Without Authenticity Token</h1>
    #            <form action="" method="post">
    #              <input type="text" name="foo">
    #              <input type="submit">
    #            </form>
    #            <h1>With Authenticity Token</h1>
    #            <form action="" method="post">
    #              <input type="text" name="foo">
    #              <input type="hidden" name="token" value="#{env['rack.session'][:csrf]}">
    #              <input type="submit">
    #            </form>
    #          </body>
    #          </html>
    #        EOS
    #      ]]
    #    end
    #  end
    #
    #  Rack::Handler::WEBrick.run app
    class AuthenticityToken < Base
      TOKEN_LENGTH = 32

      default_options :authenticity_param => 'authenticity_token',
                      :allow_if => nil

      def self.token(session)
        self.new(nil).mask_authenticity_token(session)
      end

      def self.random_token
        SecureRandom.base64(TOKEN_LENGTH)
      end

      def accepts?(env)
        session = session env
        set_token(session)

        safe?(env) ||
          valid_token?(session, env['HTTP_X_CSRF_TOKEN']) ||
          valid_token?(session, Request.new(env).params[options[:authenticity_param]]) ||
          ( options[:allow_if] && options[:allow_if].call(env) )
      end

      def mask_authenticity_token(session)
        token = set_token(session)
        mask_token(token)
      end

      private

      def set_token(session)
        session[:csrf] ||= self.class.random_token
      end

      # Checks the client's masked token to see if it matches the
      # session token.
      def valid_token?(session, token)
        return false if token.nil? || token.empty?

        begin
          token = decode_token(token)
        rescue ArgumentError # encoded_masked_token is invalid Base64
          return false
        end

        # See if it's actually a masked token or not. We should be able
        # to handle any unmasked tokens that we've issued without error.

        if unmasked_token?(token)
          compare_with_real_token token, session

        elsif masked_token?(token)
          token = unmask_token(token)

          compare_with_real_token token, session

        else
          false # Token is malformed
        end
      end

      # Creates a masked version of the authenticity token that varies
      # on each request. The masking is used to mitigate SSL attacks
      # like BREACH.
      def mask_token(token)
        token = decode_token(token)
        one_time_pad = SecureRandom.random_bytes(token.length)
        encrypted_token = xor_byte_strings(one_time_pad, token)
        masked_token = one_time_pad + encrypted_token
        encode_token(masked_token)
      end

      # Essentially the inverse of +mask_token+.
      def unmask_token(masked_token)
        # Split the token into the one-time pad and the encrypted
        # value and decrypt it
        token_length = masked_token.length / 2
        one_time_pad = masked_token[0...token_length]
        encrypted_token = masked_token[token_length..-1]
        xor_byte_strings(one_time_pad, encrypted_token)
      end

      def unmasked_token?(token)
        token.length == TOKEN_LENGTH
      end

      def masked_token?(token)
        token.length == TOKEN_LENGTH * 2
      end

      def compare_with_real_token(token, session)
        secure_compare(token, real_token(session))
      end

      def real_token(session)
        decode_token(session[:csrf])
      end

      def encode_token(token)
        Base64.strict_encode64(token)
      end

      def decode_token(token)
        Base64.strict_decode64(token)
      end

      def xor_byte_strings(s1, s2)
        s1.bytes.zip(s2.bytes).map { |(c1,c2)| c1 ^ c2 }.pack('c*')
      end
    end
  end
end
