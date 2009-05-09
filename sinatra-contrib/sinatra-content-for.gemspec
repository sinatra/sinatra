Gem::Specification.new do |s|
  s.name    = "sinatra-content-for"
  s.version = "0.2"
  s.date    = "2009-05-09"

  s.description = "Small Sinatra extension to add a content_for helper similar to Rails'"
  s.summary     = "Small Sinatra extension to add a content_for helper similar to Rails'"
  s.homepage    = "http://sinatrarb.com"

  s.authors = ["Nicolás Sanguinetti"]
  s.email   = "contacto@nicolassanguinetti.info"

  s.require_paths     = ["lib"]
  s.rubyforge_project = "sinatra-ditties"
  s.has_rdoc          = true
  s.rubygems_version  = "1.3.1"

  s.add_dependency "sinatra"

  if s.respond_to?(:add_development_dependency)
    s.add_development_dependency "contest"
    s.add_development_dependency "sr-mg"
    s.add_development_dependency "redgreen"
  end

  s.files = %w[
.gitignore
LICENSE
README.rdoc
sinatra-content-for.gemspec
lib/sinatra/content_for.rb
test/content_for_test.rb
]
end
