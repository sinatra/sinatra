# frozen_string_literal: true

version = File.read(File.expand_path('../VERSION', __dir__)).strip

Gem::Specification.new do |s|
  s.name        = 'sinatra-contrib'
  s.version     = version
  s.description = 'Collection of useful Sinatra extensions'
  s.homepage    = 'http://sinatrarb.com/contrib/'
  s.license     = 'MIT'
  s.summary     = "#{s.description}."
  s.authors     = ['https://github.com/sinatra/sinatra/graphs/contributors']
  s.email       = 'sinatrarb@googlegroups.com'
  s.files       = Dir['lib/**/*.rb'] + [
    'LICENSE',
    'README.md',
    'Rakefile',
    'ideas.md',
    'sinatra-contrib.gemspec'
  ]

  unless s.respond_to?(:metadata)
    raise <<-WARN
RubyGems 2.0 or newer is required to protect against public gem pushes. You can update your rubygems version by running:
  gem install rubygems-update
  update_rubygems:
  gem update --system
    WARN
  end

  s.metadata = {
    'source_code_uri' => 'https://github.com/sinatra/sinatra/tree/main/sinatra-contrib',
    'homepage_uri' => 'http://sinatrarb.com/contrib/',
    'documentation_uri' => 'https://www.rubydoc.info/gems/sinatra-contrib',
    'rubygems_mfa_required' => 'true'
  }

  s.required_ruby_version = '>= 2.7.8'

  s.add_dependency 'multi_json', '>= 0.0.2'
  s.add_dependency 'mustermann', '~> 3.0'
  s.add_dependency 'rack-protection', version
  s.add_dependency 'sinatra', version
  s.add_dependency 'tilt', '~> 2.0'
end
