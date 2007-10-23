require 'thread'

module Sinatra
  
  module EventManager # :nodoc:
    extend self

    def reset!
      @events.clear if @events
    end

    def events
      @events || []
    end
    
    def register_event(event)
      (@events ||= []) << event
    end
    
    def determine_event(verb, path, if_nil = :present_error)
      event = events.find(method(if_nil)) do |e|
        e.verb == verb && e.recognize(path)
      end
    end
    
    def present_error
      determine_event(:get, '404', :not_found)
    end
    
    def not_found
      Event.new(:get, 'not_found', false) do
        status 404
    
        if request.path_info == '/' && request.request_method == 'GET'
          erb :default_index, :views_directory => SINATRA_ROOT + '/files'
        else
          erb :not_found, :views_directory => SINATRA_ROOT + '/files'
        end
      end
    end
    
  end
    
  class Event # :nodoc:

    cattr_accessor :logger
    cattr_accessor :after_filters
    cattr_accessor :before_filters
    
    @@mutex = Mutex.new
    
    self.before_filters = []
    self.after_filters = []
    
    def self.before_attend(method_name = nil, &block)
      setup_filter(:before_filters, method_name, &block)
    end

    def self.after_attend(method_name = nil, &block)
      setup_filter(:after_filters, method_name, &block)
    end
    
    def self.setup_filter(filter_set_name, method_name, &block)
      raise "Must specify method or block" if method_name.nil? and !block_given?
      send(filter_set_name) << if block_given?
        block
      else
        method_name
      end
    end
      
    after_attend :log_event
    
    attr_reader :path, :verb
    
    def initialize(verb, path, register = true, &block)
      @verb = verb
      @path = path
      @route = Route.new(path)
      @block = block
      EventManager.register_event(self) if register
    end
    
    def attend(request)
      request.params.merge!(@route.params)
      context = EventContext.new(request)
      run_safely do
        caught = catch(:halt) do
          call_filters(before_filters, context)
        end
        body = case caught
          when :filter_chain_completed
            begin
              context.instance_eval(&@block) if @block
            rescue => e
              context.error e
            end
          when Symbol
            context.send(caught)
          when String
            caught
          when Fixnum
            context.status caught
        end
        context.body context.body || body || ''
        call_filters(after_filters, context)
      end
      context
    end
    alias :call :attend

    def recognize(path)
      @route.recognize(path)
    end

    private
    
      def run_safely
        if Options.use_mutex?
          @@mutex.synchronize do
            yield
          end
        else
          yield
        end
      end
      
      # Adapted from Merb
      # calls a filter chain according to rules.
      def call_filters(filter_set, context)
        filter_set.each do |filter|
          case filter
            when Symbol, String
             context.send(filter)
            when Proc
             context.instance_eval(&filter)
          end
        end
        :filter_chain_completed
      end
      
  end
  
  class StaticEvent < Event # :nodoc:
    
    def initialize(path, root, register = true)
      @root = root
      super(:get, path, register)
    end

    def recognize(path)
      filename = physical_path_for(path)
      File.exists?(filename) && File.file?(filename)
    end
    
    def physical_path_for(path)
      path.gsub(/^#{@path}/, @root)
    end
    
    def attend(request)
      @filename = physical_path_for(request.path_info)
      context = EventContext.new(request)
      context.body self
      context.header 'Content-Type' => MIME_TYPES[File.extname(@filename)[1..-1]]
      context.header 'Content-Length' => File.size(@filename).to_s
      context
    end
    
    def each
      File.open(@filename, "rb") do |file|
        while part = file.read(8192)
          yield part
        end
      end
    end
    
    # :stopdoc:
    # From WEBrick.
    MIME_TYPES = {
      "ai"    => "application/postscript",
      "asc"   => "text/plain",
      "avi"   => "video/x-msvideo",
      "bin"   => "application/octet-stream",
      "bmp"   => "image/bmp",
      "class" => "application/octet-stream",
      "cer"   => "application/pkix-cert",
      "crl"   => "application/pkix-crl",
      "crt"   => "application/x-x509-ca-cert",
     #"crl"   => "application/x-pkcs7-crl",
      "css"   => "text/css",
      "dms"   => "application/octet-stream",
      "doc"   => "application/msword",
      "dvi"   => "application/x-dvi",
      "eps"   => "application/postscript",
      "etx"   => "text/x-setext",
      "exe"   => "application/octet-stream",
      "gif"   => "image/gif",
      "htm"   => "text/html",
      "html"  => "text/html",
      "jpe"   => "image/jpeg",
      "jpeg"  => "image/jpeg",
      "jpg"   => "image/jpeg",
      "lha"   => "application/octet-stream",
      "lzh"   => "application/octet-stream",
      "mov"   => "video/quicktime",
      "mpe"   => "video/mpeg",
      "mpeg"  => "video/mpeg",
      "mpg"   => "video/mpeg",
      "pbm"   => "image/x-portable-bitmap",
      "pdf"   => "application/pdf",
      "pgm"   => "image/x-portable-graymap",
      "png"   => "image/png",
      "pnm"   => "image/x-portable-anymap",
      "ppm"   => "image/x-portable-pixmap",
      "ppt"   => "application/vnd.ms-powerpoint",
      "ps"    => "application/postscript",
      "qt"    => "video/quicktime",
      "ras"   => "image/x-cmu-raster",
      "rb"    => "text/plain",
      "rd"    => "text/plain",
      "rtf"   => "application/rtf",
      "sgm"   => "text/sgml",
      "sgml"  => "text/sgml",
      "tif"   => "image/tiff",
      "tiff"  => "image/tiff",
      "txt"   => "text/plain",
      "xbm"   => "image/x-xbitmap",
      "xls"   => "application/vnd.ms-excel",
      "xml"   => "text/xml",
      "xpm"   => "image/x-xpixmap",
      "xwd"   => "image/x-xwindowdump",
      "zip"   => "application/zip",
    }
    # :startdoc:
  
  end  
  
end
