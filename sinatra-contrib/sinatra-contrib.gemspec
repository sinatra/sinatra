# -*- encoding: utf-8 -*-

version = File.read(File.expand_path("../../VERSION", __FILE__)).strip

Gem::Specification.new do |s|
  s.name        = "sinatra-contrib"
  s.version     = version
  s.description = "Collection of useful Sinatra extensions"
  s.homepage    = "http://www.sinatrarb.com/contrib/"
  s.license     = "MIT"
  s.summary     = s.description
  s.authors     = ["https://github.com/sinatra/sinatra/graphs/contributors"]
  s.email       = "sinatrarb@googlegroups.com"
  s.files       = Dir["lib/**/*.rb"] + [
    "LICENSE",
    "README.md",
    "Rakefile",
    "ideas.md",
    "sinatra-contrib.gemspec"
  ]

  s.required_ruby_version = '>= 2.2.0'

  s.add_dependency "sinatra", version
  s.add_dependency "mustermann", "~> 1.0"
  s.add_dependency "backports", ">= 2.8.2"
  s.add_dependency "activesupport", ">= 4.0.0"
  s.add_dependency "tilt",      ">= 1.3", "< 3"
  s.add_dependency "rack-protection", version
  s.add_dependency "multi_json"

  s.add_development_dependency "rspec", "~> 3.4"
  s.add_development_dependency "haml"
  s.add_development_dependency "erubis"
  s.add_development_dependency "slim"
  s.add_development_dependency "less"
  s.add_development_dependency "sass"
  s.add_development_dependency "builder"
  s.add_development_dependency "liquid"
  s.add_development_dependency "redcarpet"
  s.add_development_dependency "RedCloth", "~> 4.2.9"
  s.add_development_dependency "asciidoctor"
  s.add_development_dependency "radius"
  s.add_development_dependency "coffee-script"
  s.add_development_dependency "nokogiri"
  s.add_development_dependency "creole"
  s.add_development_dependency "wikicloth"
  s.add_development_dependency "markaby"
  s.add_development_dependency "rake", "< 11"
  s.add_development_dependency "rack-test"
end
