module Sinatra
  module ContentFor
    def content_for(key, &block)
      content_blocks[key.to_sym] << block
    end

    def yield_content(key)
      content_blocks[key.to_sym].each {|content| content.call }
    end

    private

      def content_blocks
        @content_blocks ||= Hash.new {|h,k| h[k] = [] }
      end
  end

  helpers ContentFor
end
