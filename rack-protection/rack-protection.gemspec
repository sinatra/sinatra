$:.unshift File.expand_path("../../rack-protection/lib", __FILE__)
require "rack/protection/version"

Gem::Specification.new do |s|
  # general infos
  s.name        = "rack-protection"
  s.version     = Rack::Protection::VERSION
  s.description = "Protect against typical web attacks, works with all Rack apps, including Rails."
  s.homepage    = "http://github.com/sinatra/sinatra/tree/master/rack-protection"
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

  s.files = Dir["lib/**/*.rb"] + [
    "License",
    "README.md",
    "Rakefile",
    "Gemfile",
    "rack-protection.gemspec"
  ]

  # dependencies
  s.add_dependency "rack"
  s.add_development_dependency "rack-test"
  s.add_development_dependency "rspec", "~> 3.0.0"
end
