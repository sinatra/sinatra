# The request object. See Rack::Request for more info:
# http://rack.rubyforge.org/doc/classes/Rack/Request.html
module Sinatra
  class Request < Rack::Request
    HEADER_PARAM = /\s*[\w.]+=(?:[\w.]+|"(?:[^"\\]|\\.)*")?\s*/
    HEADER_VALUE_WITH_PARAMS = /(?:(?:\w+|\*)\/(?:\w+(?:\.|\-|\+)?|\*)*)\s*(?:;#{HEADER_PARAM})*/

    # Returns an array of acceptable media types for the response
    def accept
      @env['sinatra.accept'] ||= begin
        entries = @env['HTTP_ACCEPT'].to_s.scan(HEADER_VALUE_WITH_PARAMS)
        entries.map { |e| AcceptEntry.new(e) }.sort
      end
    end

    def preferred_type(*types)
      accepts = accept # just evaluate once
      return accepts.first if types.empty?
      types.flatten!
      return types.first if accepts.empty?
      accepts.detect do |pattern|
        type = types.detect { |t| File.fnmatch(pattern, t) }
        return type if type
      end
    end

    alias accept? preferred_type
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

    private

    class AcceptEntry
      attr_accessor :params

      def initialize(entry)
        params = entry.scan(HEADER_PARAM).map do |s|
          key, value = s.strip.split('=', 2)
          value = value[1..-2].gsub(/\\(.)/, '\1') if value.start_with?('"')
          [key, value]
        end

        @entry  = entry
        @type   = entry[/[^;]+/].delete(' ')
        @params = Hash[params]
        @q      = @params.delete('q') { "1.0" }.to_f
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
  end
end
