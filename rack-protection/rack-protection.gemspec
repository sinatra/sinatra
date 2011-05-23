# Run `rake rack-protection.gemspec` to update the gemspec.
Gem::Specification.new do |s|
  # general infos
  s.name        = "rack-protection"
  s.version     = "0.0.1"
  s.description = "You should use protection!"
  s.homepage    = "http://github.com/rkh/rack-protection"
  s.summary     = s.description

  # generated from git shortlog -sn
  s.authors = [
    "Konstantin Haase"
  ]

  # generated from git shortlog -sne
  s.email = [
    "konstantin.mailinglists@googlemail.com"
  ]

  # generated from git ls-files
  s.files = [
    "License",
    "README.md",
    "Rakefile",
    "lib/rack-protection.rb",
    "lib/rack/protection.rb",
    "lib/rack/protection/version.rb",
    "rack-protection.gemspec",
    "spec/rack_protection_spec.rb"
  ]

  # dependencies
  s.add_dependency "rack"
  s.add_development_dependency "rack-test"
  s.add_development_dependency "rspec", "~> 2.0"
end
