require 'rack/protection'

module Rack
  module Protection
    class FrameOptions < XSSHeader
      default_options :frame_options => :sameorigin
      def header
        { 'X-Frame-Options' => options[:frame_options].to_s }
      end
    end
  end
end
