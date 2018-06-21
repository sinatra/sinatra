version = File.read(File.expand_path("../../VERSION", __FILE__)).strip

Gem::Specification.new do |s|
  # general infos
  s.name        = "rack-protection"
  s.version     = version
  s.description = "Protect against typical web attacks, works with all Rack apps, including Rails."
  s.homepage    = "http://sinatrarb.com/protection/"
  s.summary     = s.description
  s.license     = 'MIT'
  s.authors     = ["https://github.com/sinatra/sinatra/graphs/contributors"]
  s.email       = "sinatrarb@googlegroups.com"
  s.files       = Dir["lib/**/*.rb"] + [
    "License",
    "README.md",
    "Rakefile",
    "Gemfile",
    "rack-protection.gemspec"
  ]
  s.metadata = {
    'source_code_uri' => 'https://github.com/sinatra/sinatra/tree/master/rack-protection'
    'homepage_uri'      => 'http://sinatrarb.com/protection/',
    'documentation_uri' => 'https://www.rubydoc.info/gems/rack-protection'
  }

  # dependencies
  s.add_dependency "rack"
  s.add_development_dependency "rack-test"
  s.add_development_dependency "rspec", "~> 3.6"
end
