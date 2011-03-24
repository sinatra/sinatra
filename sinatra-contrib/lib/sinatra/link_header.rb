require 'sinatra/base'

module Sinatra
  ##
  # Helper methods for generating Link HTTP headers and HTML tags.
  module LinkHeader
    ##
    # Set Link HTTP header and returns HTML tags for telling the browser to
    # prefetch given resources (only supported by Opera and Firefox at the 
    # moment).
    def prefetch(*urls)
      link(:prefetch, *urls)
    end

    ##
    # Sets Link HTTP header and returns HTML tags for using stylesheets.
    def stylesheet(*urls)
      urls << {} unless urls.last.respond_to? :to_hash
      urls.last[:type] ||= mime_type(:css)
      link(:stylesheet, *urls)
    end

    ##
    # Sets Link HTTP header and returns corresponding HTML tags.
    #
    # Example:
    #
    #   # Sets header:
    #   #   Link: </foo>; rel="next"
    #   # Returns String:
    #   #   '<link href="/foo" rel="next" />'
    #   link '/foo', :rel => :next
    #
    #   # Multiple URLs
    #   link :stylesheet, '/a.css', '/b.css'
    def link(*urls)
      opts          = urls.last.respond_to?(:to_hash) ? urls.pop : {}
      opts[:rel]    = urls.shift unless urls.first.respond_to? :to_str
      options       = opts.map { |k, v| " #{k}=#{v.to_s.inspect}" }
      html_pattern  = "<link href=\"%s\"#{options.join} />"
      http_pattern  = ["<%s>", *options].join ";"
      link          = (response["Link"] ||= "")

      urls.map do |url|
        link << "\n" unless link.empty?
        link << (http_pattern % url)
        html_pattern % url
      end.join "\n"
    end

    ##
    # Takes the current value of th Link header(s) and generates HTML tags
    # from it.
    #
    # Example:
    #
    #   get '/' do
    #     # You can of course use fancy helpers like #link, #stylesheet
    #     # or #prefetch
    #     response["Link"] = '</foo>; rel="next"'
    #     haml :some_page
    #   end
    #
    #   __END__
    #
    #   @@ layout
    #   %head= link_headers
    #   %body= yield
    def link_headers
      yield if block_given?
      return "" unless response.include? "Link"
      response["Link"].lines.map do |line|
        url, *opts = line.split(';').map(&:strip)
        "<link href=\"#{url[1..-2]}\" #{opts.join " "} />"
      end.join "\n"
    end

    def self.registered(base)
      puts "WARNING: #{self} is a helpers module, not an extension."
    end
  end

  helpers LinkHeader
end
