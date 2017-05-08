# Rack::Protection

[![Build Status](https://secure.travis-ci.org/sinatra/rack-protection.svg)](http://travis-ci.org/sinatra/rack-protection)

This gem protects against typical web attacks.
Should work for all Rack apps, including Rails.

# Usage

Use all protections you probably want to use:

``` ruby
# config.ru
require 'rack/protection'
use Rack::Protection
run MyApp
```

Skip a single protection middleware:

``` ruby
# config.ru
require 'rack/protection'
use Rack::Protection, :except => :path_traversal
run MyApp
```

Use a single protection middleware:

``` ruby
# config.ru
require 'rack/protection'
use Rack::Protection::AuthenticityToken
run MyApp
```

# Prevented Attacks

## Cross Site Request Forgery

Prevented by:

* `Rack::Protection::AuthenticityToken` (not included by `use Rack::Protection`)
* `Rack::Protection::FormToken` (not included by `use Rack::Protection`)
* `Rack::Protection::JsonCsrf`
* `Rack::Protection::RemoteReferrer` (not included by `use Rack::Protection`)
* `Rack::Protection::RemoteToken`
* `Rack::Protection::HttpOrigin`

## Cross Site Scripting

Prevented by:

* `Rack::Protection::EscapedParams` (not included by `use Rack::Protection`)
* `Rack::Protection::XSSHeader` (Internet Explorer and Chrome only)
* `Rack::Protection::ContentSecurityPolicy`

## Clickjacking

Prevented by:

* `Rack::Protection::FrameOptions`

## Directory Traversal

Prevented by:

* `Rack::Protection::PathTraversal`

## Session Hijacking

Prevented by:

* `Rack::Protection::SessionHijacking`

## Cookie Tossing

Prevented by:
* `Rack::Protection::CookieTossing` (not included by `use Rack::Protection`)

## IP Spoofing

Prevented by:

* `Rack::Protection::IPSpoofing`

## Helps to protect against protocol downgrade attacks and cookie hijacking

Prevented by:

* `Rack::Protection::StrictTransport` (not included by `use Rack::Protection`)

# Installation

    gem install rack-protection

# Instrumentation

Instrumentation is enabled by passing in an instrumenter as an option.
```
use Rack::Protection, instrumenter: ActiveSupport::Notifications
```

The instrumenter is passed a namespace (String) and environment (Hash). The namespace is 'rack.protection' and the attack type can be obtained from the environment key 'rack.protection.attack'.
