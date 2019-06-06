module Sinatra
  # The request object. See Rack::Request for more info:
  # http://rubydoc.info/github/rack/rack/master/Rack/Request
  class Request < Rack::Request
    HEADER_PARAM = /\s*[\w.]+=(?:[\w.]+|"(?:[^"\\]|\\.)*")?\s*/
    HEADER_VALUE_WITH_PARAMS = /(?:(?:\w+|\*)\/(?:\w+(?:\.|\-|\+)?|\*)*)\s*(?:;#{HEADER_PARAM})*/

    # Returns an array of acceptable media types for the response
    def accept
      @env['sinatra.accept'] ||= begin
        if @env.include? 'HTTP_ACCEPT' and @env['HTTP_ACCEPT'].to_s != ''
          @env['HTTP_ACCEPT'].to_s.scan(HEADER_VALUE_WITH_PARAMS).
            map! { |e| AcceptEntry.new(e) }.sort
        else
          [AcceptEntry.new('*/*')]
        end
      end
    end

    def accept?(type)
      preferred_type(type).to_s.include?(type)
    end

    def preferred_type(*types)
      return accept.first if types.empty?
      types.flatten!
      return types.first if accept.empty?
      accept.detect do |accept_header|
        type = types.detect { |t| MimeTypeEntry.new(t).accepts?(accept_header) }
        return type if type
      end
    end

    alias secure? ssl?

    def forwarded?
      @env.include? "HTTP_X_FORWARDED_HOST"
    end

    def safe?
      get? or head? or options? or trace?
    end

    def idempotent?
      safe? or put? or delete? or link? or unlink?
    end

    def link?
      request_method == "LINK"
    end

    def unlink?
      request_method == "UNLINK"
    end

    def params
      super
    rescue Rack::Utils::ParameterTypeError, Rack::Utils::InvalidParameterError => e
      raise BadRequest, "Invalid query parameters: #{Rack::Utils.escape_html(e.message)}"
    end

    class AcceptEntry
      attr_accessor :params
      attr_reader :entry

      def initialize(entry)
        params = entry.scan(HEADER_PARAM).map! do |s|
          key, value = s.strip.split('=', 2)
          value = value[1..-2].gsub(/\\(.)/, '\1') if value.start_with?('"')
          [key, value]
        end

        @entry  = entry
        @type   = entry[/[^;]+/].delete(' ')
        @params = Hash[params]
        @q      = @params.delete('q') { 1.0 }.to_f
      end

      def <=>(other)
        other.priority <=> self.priority
      end

      def priority
        # We sort in descending order; better matches should be higher.
        [ @q, -@type.count('*'), @params.size ]
      end

      def to_str
        @type
      end

      def to_s(full = false)
        full ? entry : to_str
      end

      def respond_to?(*args)
        super or to_str.respond_to?(*args)
      end

      def method_missing(*args, &block)
        to_str.send(*args, &block)
      end
    end

    class MimeTypeEntry
      attr_reader :params

      def initialize(entry)
        params = entry.scan(HEADER_PARAM).map! do |s|
          key, value = s.strip.split('=', 2)
          value = value[1..-2].gsub(/\\(.)/, '\1') if value.start_with?('"')
          [key, value]
        end

        @type   = entry[/[^;]+/].delete(' ')
        @params = Hash[params]
      end

      def accepts?(entry)
        File.fnmatch(entry, self) && matches_params?(entry.params)
      end

      def to_str
        @type
      end

      def matches_params?(params)
        return true if @params.empty?

        params.all? { |k,v| !@params.has_key?(k) || @params[k] == v }
      end
    end
  end
end
