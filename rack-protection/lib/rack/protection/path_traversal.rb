require 'rack/protection'

module Rack
  module Protection
    ##
    # Prevented attack::   Directory traversal
    # Supported browsers:: all
    # More infos::         http://en.wikipedia.org/wiki/Directory_traversal
    #
    # Unescapes '/' and '.', expands +path_info+.
    # Thus <tt>GET /foo/%2e%2e%2fbar</tt> becomes <tt>GET /bar</tt>.
    class PathTraversal < Base
      def call(env)
        path_was         = env["PATH_INFO"]
        env["PATH_INFO"] = cleanup path_was
        app.call env
      ensure
        env["PATH_INFO"] = path_was
      end

      def cleanup(path)
        return cleanup("/" << path)[1..-1] unless path[0] == ?/
        escaped = ::File.expand_path path.gsub('%2e', '.').gsub('%2f', '/')
        escaped << '/' if escaped[-1] != ?/ and path =~ /\/\.{0,2}$/
        escaped.gsub(/\/\/+/, '/')
      end
    end
  end
end
