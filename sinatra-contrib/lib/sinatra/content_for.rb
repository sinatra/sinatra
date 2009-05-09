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
    #
    # Your blocks can also receive values, which are passed to them
    # by <tt>yield_content</tt>
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
    # You can also pass values to the content blocks by passing them
    # as arguments after the key:
    #
    #     <% yield_content :head, 1, 2 %>
    #
    # Would pass <tt>1</tt> and <tt>2</tt> to all the blocks registered
    # for <tt>:head</tt>.
    #
    # *NOTICE* that you call this without an <tt>=</tt> sign. IE, 
    # in a <tt><% %></tt> block, and not in a <tt><%= %></tt> block.
    def yield_content(key, *args)
      content_blocks[key.to_sym].map do |content| 
        if respond_to?(:block_is_haml?) && block_is_haml?(content)
          capture_haml(*args, &content)
        else
          content.call(*args)
        end
      end.join
    end

    private

      def content_blocks
        @content_blocks ||= Hash.new {|h,k| h[k] = [] }
      end
  end

  helpers ContentFor
end
