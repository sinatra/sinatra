# -*- encoding: utf-8 -*-

version = File.read(File.expand_path("../../VERSION", __FILE__)).strip

Gem::Specification.new do |s|
  s.name        = "sinatra-contrib"
  s.version     = version
  s.description = "Collection of useful Sinatra extensions"
  s.homepage    = "http://sinatrarb.com/contrib/"
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

  if s.respond_to?(:metadata)
    s.metadata = {
      'source_code_uri'   => 'https://github.com/sinatra/sinatra/tree/master/sinatra-contrib',
      'homepage_uri'      => 'http://sinatrarb.com/contrib/',
      'documentation_uri' => 'https://www.rubydoc.info/gems/sinatra-contrib'
    }
  else
    raise <<-EOF
RubyGems 2.0 or newer is required to protect against public gem pushes. You can update your rubygems version by running:
  gem install rubygems-update
  update_rubygems:
  gem update --system
EOF
  end

  s.required_ruby_version = '>= 2.3.0'

  s.add_dependency "sinatra", version
  s.add_dependency "mustermann", "~> 2.0"
  s.add_dependency "tilt", "~> 2.0"
  s.add_dependency "rack-protection", version
  s.add_dependency "multi_json"

  s.add_development_dependency "rspec", "~> 3.4"
  s.add_development_dependency "haml"
  s.add_development_dependency "erubi"
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
