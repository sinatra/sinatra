* Extension that does something like this:

      def build(*)
        if settings.memcached?
          use Rack::Cache, :backend => :memcached
          use Rack::Session::Memcached
          # ...
        end
        super
      end

* `sinatra-smart-cache`: update cache header only if arguments are more
  restrictive than current value, set caching headers that way for most helper
  methods (i.e. `send_file`)

* Some verbose logging extension: Log what filters, routes, error handlers,
  templates, and so on is used.

* Form helpers, with forms as first class objects that accepts hashes or
  something, so the form meta data can also be used to expose a JSON API or
  similar, possibly defining routes (like "Sinatra's Hat"), strictly using
  the ActiveModel API.

* Extend `sinatra-content-for` to support Liquid, Radius, Markaby, Nokogiri and
  Builder. At least the first two probably involve patching Tilt.

* Rewrite of `sinatra-compass`?

* Helpers for HTML escaping and such.
