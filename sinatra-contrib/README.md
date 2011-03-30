Collection of common Sinatra extensions, semi-officially supported.

# Goals

* For every future Sinatra release, have at least one fully compatible release
* High code quality, high test coverage
* Include plugins people usually ask for a lot

# TODO

* Write documentation, integrate into Sinatra website
* Finish imports and rewrites
* Wrap up first release
* Find contributors (both code and docs)

# Included extensions

## Common Extensions

These are common extension which will not add significant overhead or change any
behavior of already existing APIs. They do not add any dependencies not already
installed with this gem.

Currently included:

* `sinatra/config_file`: Allows loading configuration from yaml files.

* `sinatra/content_for`: Adds Rails-style `content_for` helpers to Haml, Erb,
  Erubis and Slim.


* `sinatra/link_header`: Helpers for generating `link` HTML tags and
  corresponding `Link` HTTP headers. Adds `link`, `stylesheet` and `prefetch`
  helper methods.

* `sinatra/respond_with`: Choose action and/or template depending automatically
  depending on the incoming request. Adds helpers `respond_to` and
  `respond_with`.


To be included soon:

* Helpers for CSS/JS generation (currently in `sinatra-support`)

* Rewrite of `sinatra-reloader`

## Custom Extensions

These extensions may add additional dependencies and enhance the behavior of the
existing APIs.

Currently included:

* `sinatra/decompile`: Recreates path patterns from Sinatra's internal data
  structures (used by other extensions)/

To be included soon:

* Rewrite of `sinatra-compass`

## Other Tools

* `sinatra/extension`: Mixin for writing your own Sinatra extensions.

* `sinatra/test_helpers`: Helper methods to ease testing your Sinatra
  application. Partly extracted from Sinatra. Testing framework agnostic

# Usage

## Classic Style

A single extension (example: sinatra-content-for):

    require 'sinatra'
    require 'sinatra/content_for'

Common extensions:

    require 'sinatra'
    require 'sinatra/contrib'

All extensions:

    require 'sinatra'
    require 'sinatra/contrib/all'

## Modular Style

A single extension (example: sinatra-content-for):

    require 'sinatra/base'
    require 'sinatra/content_for'
    
    class MyApp < Sinatra::Base
      register Sinatra::ContentFor
    end

Common extensions:

    require 'sinatra/base'
    require 'sinatra/contrib'
    
    class MyApp < Sinatra::Base
      register Sinatra::Contrib
    end

All extensions:

    require 'sinatra/base'
    require 'sinatra/contrib'
    
    class MyApp < Sinatra::Base
      register Sinatra::Contrib
    end
