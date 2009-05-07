module Sinatra
  module ContentFor
    # Capture a block of content to be rendered later. For example:
    #
    #     <% content_for :head do %>
    #       <script type="text/javascript" src="/foo.js"></script>
    #     <% end %>
    #
    # You can call +content_for+ multiple times with the same key
    # (in the example +:head+), and when you render the blocks for
    # that key all of them will be rendered, in the same order you
    # captured them.
    def content_for(key, &block)
      content_blocks[key.to_sym] << block
    end

    # Render the captured blocks for a given key. For example:
    #
    #     <head>
    #       <title>Example</title>
    #       <% yield_content :head %>
    #     </head>
    #
    # Would render everything you declared with <tt>content_for 
    # :head</tt> before closing the <tt><head></tt> tag.
    #
    # *NOTICE* that you call this without an <tt>=</tt> sign. IE, 
    # in a <tt><% %></tt> block, and not in a <tt><%= %></tt> block.
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
