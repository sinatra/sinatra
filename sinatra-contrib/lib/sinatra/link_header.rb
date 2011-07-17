require 'sinatra/base'

module Sinatra

  # = Sinatra::LinkHeader
  #
  # <tt>Sinatra::LinkHeader</tt> adds a set of helper methods to generate link
  # HTML tags and their corresponding Link HTTP headers.
  #
  # == Usage
  #
  # Once you had set up the helpers in your application (see below), you will
  # be able to call the following methods from inside your route handlers,
  # filters and templates:
  #
  # +prefetch+::
  #     Sets the Link HTTP headers and returns HTML tags to prefetch the given
  #     resources.
  #
  # +stylesheet+::
  #     Sets the Link HTTP headers and returns HTML tags to use the given
  #     stylesheets.
  #
  # +link+::
  #     Sets the Link HTTP headers and returns the corresponding HTML tags
  #     for the given resources.
  #
  # +link_headers+::
  #     Returns the corresponding HTML tags for the current Link HTTP headers.
  #
  # === Classic Application
  #
  # In a classic application simply require the helpers, and start using them:
  #
  #     require "sinatra"
  #     require "sinatra/link_header"
  #
  #     # The rest of your classic application code goes here...
  #
  # === Modular Application
  #
  # In a modular application you need to require the helpers, and then tell
  # the application you will use them:
  #
  #     require "sinatra/base"
  #     require "sinatra/link_header"
  #
  #     class MyApp < Sinatra::Base
  #       helpers Sinatra::LinkHeader
  #
  #       # The rest of your modular application code goes here...
  #     end
  #
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
