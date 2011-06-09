Kernel.load './lib/sinatra/version.rb'

Gem::Specification.new 'sinatra', Sinatra::VERSION do |s|
  s.description       = "Classy web-development dressed in a DSL"
  s.summary           = s.description
  s.authors           = ["Blake Mizerany", "Ryan Tomayko", "Simon Rozet", "Konstantin Haase"]
  s.email             = "sinatrarb@googlegroups.com"
  s.homepage          = "http://www.sinatrarb.com/"
  s.files             = `git ls-files`.split("\n")
  s.test_files        = s.files.select { |p| p =~ /^test\/.*_test.rb/ }
  s.extra_rdoc_files  = s.files.select { |p| p =~ /^README/ } << 'LICENSE'
  s.rdoc_options      = %w[--line-numbers --inline-source --title Sinatra --main README.rdoc]

  s.add_dependency 'rack', '~> 1.3'
  s.add_dependency 'tilt', '~> 1.3'
end
