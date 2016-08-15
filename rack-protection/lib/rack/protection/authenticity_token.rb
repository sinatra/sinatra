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
    # Compatible with Rails and rack-csrf.
    #
    # Options:
    #
    # authenticity_param: Defines the param's name that should contain the token on a request.
    #
    class AuthenticityToken < Base
      default_options :authenticity_param => 'authenticity_token',
                      :authenticity_token_length => 32,
                      :allow_if => nil

      class << self
        def token(session)
          mask_token(session[:csrf])
        end

        def random_token(length = 32)
          SecureRandom.base64(length)
        end

        # Creates a masked version of the authenticity token that varies
        # on each request. The masking is used to mitigate SSL attacks
        # like BREACH.
        def mask_token(token)
          token = decode_token(token)
          one_time_pad = SecureRandom.random_bytes(token.length)
          encrypted_token = xor_byte_strings(one_time_pad, token)
          masked_token = one_time_pad + encrypted_token
          encode_token masked_token
        end

        # Essentially the inverse of +mask_token+.
        def unmask_decoded_token(masked_token)
          # Split the token into the one-time pad and the encrypted
          # value and decrypt it
          token_length = masked_token.length / 2
          one_time_pad = masked_token[0...token_length]
          encrypted_token = masked_token[token_length..-1]
          xor_byte_strings(one_time_pad, encrypted_token)
        end

        def encode_token(token)
          Base64.strict_encode64(token)
        end

        def decode_token(token)
          Base64.strict_decode64(token)
        end

        private

        def xor_byte_strings(s1, s2)
          s1.bytes.zip(s2.bytes).map { |(c1,c2)| c1 ^ c2 }.pack('c*')
        end
      end

      def accepts?(env)
        session = session env
        session[:csrf] ||= self.class.random_token(token_length)

        safe?(env) ||
          valid_token?(session, env['HTTP_X_CSRF_TOKEN']) ||
          valid_token?(session, Request.new(env).params[options[:authenticity_param]]) ||
          ( options[:allow_if] && options[:allow_if].call(env) )
      end

      private

      def token_length
        options[:authenticity_token_length]
      end

      # Checks the client's masked token to see if it matches the
      # session token.
      def valid_token?(session, token)
        return false if token.nil? || token.empty?

        begin
          token = self.class.decode_token(token)
        rescue ArgumentError # encoded_masked_token is invalid Base64
          return false
        end

        # See if it's actually a masked token or not. We should be able
        # to handle any unmasked tokens that we've issued without error.

        if unmasked_token?(token)
          compare_with_real_token token, session

        elsif masked_token?(token)
          token = self.class.unmask_decoded_token(token)

          compare_with_real_token token, session

        else
          false # Token is malformed
        end
      end

      def unmasked_token?(token)
        token.length == token_length
      end

      def masked_token?(token)
        token.length == token_length * 2
      end

      def compare_with_real_token(token, session)
        secure_compare(token, real_token(session))
      end

      def real_token(session)
        self.class.decode_token(session[:csrf])
      end
    end
  end
end
