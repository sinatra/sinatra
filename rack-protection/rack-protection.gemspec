$:.unshift File.expand_path("../../rack-protection/lib", __FILE__)
require "rack/protection/version"

Gem::Specification.new do |s|
  # general infos
  s.name        = "rack-protection"
  s.version     = Rack::Protection::VERSION
  s.description = "Protect against typical web attacks, works with all Rack apps, including Rails."
  s.homepage    = "http://github.com/sinatra/rack-protection"
  s.summary     = s.description
  s.license     = 'MIT'

  # generated from git shortlog -sn
  s.authors = [
    "Konstantin Haase",
    "Maurizio De Santis",
    "Alex Rodionov",
    "Jason Staten",
    "Patrick Ellis",
    "ITO Nobuaki",
    "Jeff Welling",
    "Matteo Centenaro",
    "Akzhan Abdulin",
    "Alan deLevie",
    "Bj\u{f8}rge N\u{e6}ss",
    "Chris Heald",
    "Chris Mytton",
    "Corey Ward",
    "Dario Cravero",
    "David Kellum",
    "Egor Homakov",
    "Florian Gilcher",
    "Fojas",
    "Igor Bochkariov",
    "Josef Stribny",
    "Katrina Owen",
    "Mael Clerambault",
    "Martin Mauch",
    "Renne Nissinen",
    "SAKAI, Kazuaki",
    "Stanislav Savulchik",
    "Steve Agalloco",
    "TOBY",
    "Thais Camilo and Konstantin Haase",
    "Vipul A M",
    "Zachary Scott",
    "ashley williams",
    "brookemckim"
  ]

  # generated from git shortlog -sne
  s.email = [
    "mail@zzak.io",
    "konstantin.haase@gmail.com"
  ]

  # generated from git ls-files
  s.files = [
    "License",
    "README.md",
    "Rakefile",
    "Gemfile",
    "rack-protection.gemspec",
    "lib/rack",
    "lib/rack/protection",
    "lib/rack/protection/escaped_params.rb",
    "lib/rack/protection/remote_referrer.rb",
    "lib/rack/protection/ip_spoofing.rb",
    "lib/rack/protection/base.rb",
    "lib/rack/protection/session_hijacking.rb",
    "lib/rack/protection/authenticity_token.rb",
    "lib/rack/protection/version.rb",
    "lib/rack/protection/path_traversal.rb",
    "lib/rack/protection/form_token.rb",
    "lib/rack/protection/json_csrf.rb",
    "lib/rack/protection/http_origin.rb",
    "lib/rack/protection/frame_options.rb",
    "lib/rack/protection/xss_header.rb",
    "lib/rack/protection/remote_token.rb",
    "lib/rack/protection.rb",
    "lib/rack-protection.rb"
  ]

  # dependencies
  s.add_dependency "rack"
  s.add_development_dependency "rack-test"
  s.add_development_dependency "rspec", "~> 3.0.0"
end
