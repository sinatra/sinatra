require 'sinatra/base'
require 'sinatra/capture'

module Sinatra

  # = Sinatra::ContentFor
  #
  # <tt>Sinatra::ContentFor</tt> is a set of helpers that allows you to capture
  # blocks inside views to be rendered later during the request. The most
  # common use is to populate different parts of your layout from your view.
  #
  # The currently supported engines are: Erb, Erubi, Erubis, Haml and Slim.
  #
  # == Usage
  #
  # You call +content_for+, generally from a view, to capture a block of markup
  # giving it an identifier:
  #
  #     # index.erb
  #     <% content_for :some_key do %>
  #       <chunk of="html">...</chunk>
  #     <% end %>
  #
  # Then, you call +yield_content+ with that identifier, generally from a
  # layout, to render the captured block:
  #
  #     # layout.erb
  #     <%= yield_content :some_key %>
  #
  # If you have provided +yield_content+ with a block and no content for the
  # specified key is found, it will render the results of the block provided
  # to yield_content.
  #
  #     # layout.erb
  #     <% yield_content :some_key_with_no_content do %>
  #       <chunk of="default html">...</chunk>
  #     <% end %>
  #
  # === Classic Application
  #
  # To use the helpers in a classic application all you need to do is require
  # them:
  #
  #     require "sinatra"
  #     require "sinatra/content_for"
  #
  #     # Your classic application code goes here...
  #
  # === Modular Application
  #
  # To use the helpers in a modular application you need to require them, and
  # then, tell the application you will use them:
  #
  #     require "sinatra/base"
  #     require "sinatra/content_for"
  #
  #     class MyApp < Sinatra::Base
  #       helpers Sinatra::ContentFor
  #
  #       # The rest of your modular application code goes here...
  #     end
  #
  # == And How Is This Useful?
  #
  # For example, some of your views might need a few javascript tags and
  # stylesheets, but you don't want to force this files in all your pages.
  # Then you can put <tt><%= yield_content :scripts_and_styles %></tt> on your
  # layout, inside the <head> tag, and each view can call <tt>content_for</tt>
  # setting the appropriate set of tags that should be added to the layout.
  #
  # == Limitations
  #
  # Due to the rendering process limitation using <tt><%= yield_content %></tt>
  # from within nested templates do not work above the <tt><%= yield %> statement.
  # For more details https://github.com/sinatra/sinatra-contrib/issues/140#issuecomment-48831668
  #
  #     # app.rb
  #     get '/' do
  #       erb :body, :layout => :layout do
  #         erb :foobar
  #       end
  #     end
  #
  #     # foobar.erb
  #     <% content_for :one do %>
  #       <script>
  #         alert('one');
  #       </script>
  #     <% end %>
  #     <% content_for :two do %>
  #       <script>
  #         alert('two');
  #       </script>
  #     <% end %>
  #
  # Using <tt><%= yield_content %></tt> before <tt><%= yield %></tt> will cause only the second
  # alert to display:
  #
  #     # body.erb
  #     # Display only second alert
  #     <%= yield_content :one %>
  #     <%= yield %>
  #     <%= yield_content :two %>
  #
  #     # body.erb
  #     # Display both alerts
  #     <%= yield %>
  #     <%= yield_content :one %>
  #     <%= yield_content :two %>
  #
  module ContentFor
    include Capture

    # Capture a block of content to be rendered later. For example:
    #
    #     <% content_for :head do %>
    #       <script type="text/javascript" src="/foo.js"></script>
    #     <% end %>
    #
    # You can also pass an immediate value instead of a block:
    #
    #     <% content_for :title, "foo" %>
    #
    # You can call +content_for+ multiple times with the same key
    # (in the example +:head+), and when you render the blocks for
    # that key all of them will be rendered, in the same order you
    # captured them.
    #
    # Your blocks can also receive values, which are passed to them
    # by <tt>yield_content</tt>
    def content_for(key, value = nil, options = {}, &block)
      block ||= proc { |*| value }
      clear_content_for(key) if options[:flush]
      content_blocks[key.to_sym] << capture_later(&block)
    end

    # Check if a block of content with the given key was defined. For
    # example:
    #
    #     <% content_for :head do %>
    #       <script type="text/javascript" src="/foo.js"></script>
    #     <% end %>
    #
    #     <% if content_for? :head %>
    #       <span>content "head" was defined.</span>
    #     <% end %>
    def content_for?(key)
      content_blocks[key.to_sym].any?
    end

    # Unset a named block of content. For example:
    #
    #    <% clear_content_for :head %>
    def clear_content_for(key)
      content_blocks.delete(key.to_sym) if content_for?(key)
    end

    # Render the captured blocks for a given key. For example:
    #
    #     <head>
    #       <title>Example</title>
    #       <%= yield_content :head %>
    #     </head>
    #
    # Would render everything you declared with <tt>content_for
    # :head</tt> before closing the <tt><head></tt> tag.
    #
    # You can also pass values to the content blocks by passing them
    # as arguments after the key:
    #
    #     <%= yield_content :head, 1, 2 %>
    #
    # Would pass <tt>1</tt> and <tt>2</tt> to all the blocks registered
    # for <tt>:head</tt>.
    def yield_content(key, *args, &block)
      if block_given? && !content_for?(key)
        (haml? && Tilt[:haml] == Tilt::HamlTemplate) ? capture_haml(*args, &block) : yield(*args)
      else
        content = content_blocks[key.to_sym].map { |b| capture(*args, &b) }
        content.join.tap do |c|
          if block_given? && (erb? || erubi? || erubis?)
            @_out_buf << c
          end
        end
      end
    end

    private

    def content_blocks
      @content_blocks ||= Hash.new { |h, k| h[k] = [] }
    end
  end

  helpers ContentFor
end
