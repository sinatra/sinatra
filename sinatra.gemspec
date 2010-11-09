Gem::Specification.new do |s|
  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=

  s.name = 'sinatra'
  s.version = '1.1.0'
  s.date = '2010-10-24'

  s.description = "Classy web-development dressed in a DSL"
  s.summary     = "Classy web-development dressed in a DSL"

  s.authors = ["Blake Mizerany", "Ryan Tomayko", "Simon Rozet", "Konstantin Haase"]
  s.email = "sinatrarb@googlegroups.com"

  s.files         = `git ls-files README* AUTHORS CHANGES LICENSE Rakefile Gemfile lib/`.split("\n")
  s.test_files    = `git ls-files test/`.split("\n")
  s.require_paths = ["lib"]

  s.extra_rdoc_files = `git ls-files README* LICENSE`.split("\n")

  s.add_dependency 'rack', '~> 1.1'
  s.add_dependency 'tilt', '~> 1.1'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'shotgun', '~> 0.6'
  s.add_development_dependency 'rack-test', '>= 0.5.6'
  s.add_development_dependency 'haml', '>= 3.0'
  s.add_development_dependency 'builder'
  s.add_development_dependency 'erubis'
  s.add_development_dependency 'less'
  s.add_development_dependency 'liquid'
  s.add_development_dependency 'rdiscount'
  s.add_development_dependency 'RedCloth'
  s.add_development_dependency 'radius'
  s.add_development_dependency 'markaby'
  s.add_development_dependency 'coffee-script'
  s.add_development_dependency 'rdoc'
  s.add_development_dependency 'nokogiri'

  s.has_rdoc = true
  s.homepage = "http://sinatra.rubyforge.org"
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Sinatra", "--main", "README.rdoc"]

  s.rubyforge_project = 'sinatra'
  s.rubygems_version = '1.1.1'
end
