# Sinatra::Contrib

Collection of common Sinatra extensions, semi-officially supported.

## Goals

* For every future Sinatra release, have at least one fully compatible release
* High code quality, high test coverage
* Include plugins people usually ask for a lot

## Included extensions

### Common Extensions

These are common extension which will not add significant overhead or change any
behavior of already existing APIs. They do not add any dependencies not already
installed with this gem.

Currently included:

* [`sinatra/capture`][sinatra-capture]: Let's you capture the content of blocks in templates.

* [`sinatra/config_file`][sinatra-config-file]: Allows loading configuration from yaml files.

* [`sinatra/content_for`][sinatra-content-for]: Adds Rails-style `content_for` helpers to Haml, Erb, Erubi
  and Slim.

* [`sinatra/cookies`][sinatra-cookies]: A `cookies` helper for reading and writing cookies.

* [`sinatra/engine_tracking`][sinatra-engine-tracking]: Adds methods like `haml?` that allow helper
  methods to check whether they are called from within a template.

* [`sinatra/json`][sinatra-json]: Adds a `#json` helper method to return JSON documents.

* [`sinatra/link_header`][sinatra-link-header]: Helpers for generating `link` HTML tags and
  corresponding `Link` HTTP headers. Adds `link`, `stylesheet` and `prefetch`
  helper methods.

* [`sinatra/multi_route`][sinatra-multi-route]: Adds ability to define one route block for multiple
  routes and multiple or custom HTTP verbs.

* [`sinatra/namespace`][sinatra-namespace]: Adds namespace support to Sinatra.

* [`sinatra/respond_with`][sinatra-respond-with]: Choose action and/or template automatically
  depending on the incoming request. Adds helpers `respond_to` and
  `respond_with`.

* [`sinatra/custom_logger`][sinatra-custom-logger]: This extension allows you to define your own
  logger instance using +logger+ setting. That logger then will
  be available as #logger helper method in your routes and views.

* [`sinatra/required_params`][sinatra-required-params]: Ensure if required query parameters exist

### Custom Extensions

These extensions may add additional dependencies and enhance the behavior of the
existing APIs.

Currently included:

* [`sinatra/reloader`][sinatra-reloader]: Automatically reloads Ruby files on code changes. **DEPRECATED**: Please consider
consider using an alternative like [rerun](https://github.com/alexch/rerun) or
[rack-unreloader](https://github.com/jeremyevans/rack-unreloader) instead.

### Other Tools

* [`sinatra/extension`][sinatra-extension]: Mixin for writing your own Sinatra extensions.

* [`sinatra/test_helpers`][sinatra-test-helpers]: Helper methods to ease testing your Sinatra
  application. Partly extracted from Sinatra. Testing framework agnostic

* `sinatra/quiet_logger`: Extension to exclude specific paths from access log.
  It works by patching Rack::CommonLogger

## Installation

Add `gem 'sinatra-contrib'` to *Gemfile*, then execute `bundle install`.

If you don't use Bundler, install the gem manually by executing `gem install sinatra-contrib` in your command line.

### Git

If you want to use the gem from git, for whatever reason, you can do the following:

```ruby
github 'sinatra/sinatra' do
  gem 'sinatra-contrib'
end
```

Within this block you can also specify other gems from this git repository.

## Usage

### Classic Style

A single extension (example: sinatra-content-for):

``` ruby
require 'sinatra'
require 'sinatra/content_for'
```

Common extensions:

``` ruby
require 'sinatra'
require 'sinatra/contrib'
```

All extensions:

``` ruby
require 'sinatra'
require 'sinatra/contrib/all'
```

### Modular Style

A single extension (example: sinatra-content-for):

``` ruby
require 'sinatra/base'
require 'sinatra/content_for'
require 'sinatra/namespace'

class MyApp < Sinatra::Base
  # Note: Some modules are extensions, some helpers, see the specific
  # documentation or the source
  helpers Sinatra::ContentFor
  register Sinatra::Namespace
end
```

Common extensions:

``` ruby
require 'sinatra/base'
require 'sinatra/contrib'

class MyApp < Sinatra::Base
  register Sinatra::Contrib
end
```

All extensions:

``` ruby
require 'sinatra/base'
require 'sinatra/contrib/all'

class MyApp < Sinatra::Base
  register Sinatra::Contrib
end
```

### Documentation

For more info check the [official docs](https://sinatra.run/contrib/) and
[api docs](https://www.rubydoc.info/gems/sinatra-contrib).

[sinatra-reloader]: https://sinatra.run/contrib/reloader
[sinatra-namespace]: https://sinatra.run/contrib/namespace
[sinatra-content-for]: https://sinatra.run/contrib/content_for
[sinatra-cookies]: https://sinatra.run/contrib/cookies
[sinatra-streaming]: https://sinatra.run/contrib/streaming
[sinatra-webdav]: https://sinatra.run/contrib/webdav
[sinatra-runner]: https://sinatra.run/contrib/runner
[sinatra-extension]: https://sinatra.run/contrib/extension
[sinatra-test-helpers]: https://github.com/sinatra/sinatra/blob/main/sinatra-contrib/lib/sinatra/test_helpers.rb
[sinatra-required-params]: https://sinatra.run/contrib/required_params
[sinatra-custom-logger]: https://sinatra.run/contrib/custom_logger
[sinatra-multi-route]: https://sinatra.run/contrib/multi_route
[sinatra-json]: https://sinatra.run/contrib/json
[sinatra-respond-with]: https://sinatra.run/contrib/respond_with
[sinatra-config-file]: https://sinatra.run/contrib/config_file
[sinatra-link-header]: https://sinatra.run/contrib/link_header
[sinatra-capture]: https://sinatra.run/contrib/capture
[sinatra-engine-tracking]: https://github.com/sinatra/sinatra/blob/main/sinatra-contrib/lib/sinatra/engine_tracking.rb
