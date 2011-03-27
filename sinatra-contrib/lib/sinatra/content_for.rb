module Sinatra
  ##
  # Small extension for the Sinatra[http://sinatrarb.com] web framework
  # that allows you to use the following helpers in your views:
  #
  #     <% content_for :some_key do %>
  #       <chunk of="html">...</chunk>
  #     <% end %>
  #
  #     <% yield_content :some_key %>
  #
  # This allows you to capture blocks inside views to be rendered later
  # in this request. For example, to populate different parts of your
  # layout from your view.
  #
  # When using this with the Haml rendering engine, you should do the
  # following:
  #
  #     - content_for :some_key do
  #       %chunk{ :of => "html" } ...
  #
  #     = yield_content :some_key
  #
  # <b>Note</b> that with ERB <tt>yield_content</tt> is called <b>without</b>
  # an '=' block (<tt><%= %></tt>), but with Haml it uses <tt>= yield_content</tt>.
  #
  # Using an '=' block in ERB will output the content twice for each block,
  # so if you have problems with that, make sure to check for this.
  #
  # == Usage
  #
  # If you're writing "classic" style apps, then requring
  # <tt>sinatra/content_for</tt> should be enough. If you're writing
  # "classy" apps, then you also need to call
  # <tt>helpers Sinatra::ContentFor</tt> in your app definition.
  #
  # == And how is this useful?
  #
  # For example, some of your views might need a few javascript tags and
  # stylesheets, but you don't want to force this files in all your pages.
  # Then you can put <tt><% yield_content :scripts_and_styles %></tt> on
  # your layout, inside the <head> tag, and each view can call
  # <tt>content_for</tt> setting the appropriate set of tags that should
  # be added to the layout.
  #
  # == Credits
  #
  # Code by foca[http://github.com/foca], inspired on the Ruby on Rails
  # helpers with the same name. Haml support by mattly[http://github.com/mattly].
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
