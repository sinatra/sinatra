Gem::Specification.new do |s|
  s.name          = "sinatra-contrib"
  s.version       = "1.2.0"
  s.description   = "Collection of useful Sinatra extensions"
  s.authors       = ["Konstantin Haase"]
  s.email         = "konstantin.mailinglists@googlemail.com"
  s.files         = Dir["**/*.{rb,md}"] << "LICENSE"
  s.has_rdoc      = 'yard'
  s.homepage      = "http://github.com/rkh/#{s.name}"
  s.require_paths = ["lib"]
  s.summary       = s.description

  s.add_dependency "sinatra", "~> 1.2.2"
  s.add_dependency "backports", ">= 2.0"
  s.add_dependency "rack-test"

  s.add_development_dependency "rspec", "~> 2.3"
  s.add_development_dependency "haml"
  s.add_development_dependency "erubis"
  s.add_development_dependency "slim"
  s.add_development_dependency "rake"
end
