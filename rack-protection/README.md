# Rack::Protection

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

* [`Rack::Protection::AuthenticityToken`][authenticity-token] (not included by `use Rack::Protection`)
* [`Rack::Protection::FormToken`][form-token] (not included by `use Rack::Protection`)
* [`Rack::Protection::JsonCsrf`][json-csrf]
* [`Rack::Protection::RemoteReferrer`][remote-referrer] (not included by `use Rack::Protection`)
* [`Rack::Protection::RemoteToken`][remote-token]
* [`Rack::Protection::HttpOrigin`][http-origin]

## Cross Site Scripting

Prevented by:

* [`Rack::Protection::EscapedParams`][escaped-params] (not included by `use Rack::Protection`)
* [`Rack::Protection::XSSHeader`][xss-header] (Internet Explorer and Chrome only)
* [`Rack::Protection::ContentSecurityPolicy`][content-security-policy]

## Clickjacking

Prevented by:

* [`Rack::Protection::FrameOptions`][frame-options]

## Directory Traversal

Prevented by:

* [`Rack::Protection::PathTraversal`][path-traversal]

## Session Hijacking

Prevented by:

* [`Rack::Protection::SessionHijacking`][session-hijacking]

## Cookie Tossing

Prevented by:
* [`Rack::Protection::CookieTossing`][cookie-tossing] (not included by `use Rack::Protection`)

## IP Spoofing

Prevented by:

* [`Rack::Protection::IPSpoofing`][ip-spoofing]

## Helps to protect against protocol downgrade attacks and cookie hijacking

Prevented by:

* [`Rack::Protection::StrictTransport`][strict-transport] (not included by `use Rack::Protection`)

# Installation

    gem install rack-protection

# Instrumentation

Instrumentation is enabled by passing in an instrumenter as an option.
```
use Rack::Protection, instrumenter: ActiveSupport::Notifications
```

The instrumenter is passed a namespace (String) and environment (Hash). The namespace is 'rack.protection' and the attack type can be obtained from the environment key 'rack.protection.attack'.

[authenticity-token]: /rack-protection/lib/rack/protection/authenticity_token.rb
[content-security-policy]: /rack-protection/lib/rack/protection/content_security_policy.rb
[cookie-tossing]: /rack-protection/lib/rack/protection/cookie_tossing.rb
[escaped-params]: /rack-protection/lib/rack/protection/escaped_params.rb
[form-token]: /rack-protection/lib/rack/protection/form_token.rb
[frame-options]: /rack-protection/lib/rack/protection/frame_options.rb
[http-origin]: /rack-protection/lib/rack/protection/http_origin.rb
[ip-spoofing]: /rack-protection/lib/rack/protection/ip_spoofing.rb
[json-csrf]: /rack-protection/lib/rack/protection/json_csrf.rb
[path-traversal]: /rack-protection/lib/rack/protection/path_traversal.rb
[remote-referrer]: /rack-protection/lib/rack/protection/remote_referrer.rb
[remote-token]: /rack-protection/lib/rack/protection/remote_token.rb
[session-hijacking]: /rack-protection/lib/rack/protection/session_hijacking.rb
[strict-transport]: /rack-protection/lib/rack/protection/strict_transport.rb
[xss-header]: /rack-protection/lib/rack/protection/xss_header.rb
