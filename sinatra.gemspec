# frozen_string_literal: true

version = File.read(File.expand_path('VERSION', __dir__)).strip

Gem::Specification.new 'sinatra', version do |s|
  s.description       = 'Sinatra is a DSL for quickly creating web applications in Ruby with minimal effort.'
  s.summary           = 'Classy web-development dressed in a DSL'
  s.authors           = ['Blake Mizerany', 'Ryan Tomayko', 'Simon Rozet', 'Konstantin Haase']
  s.email             = 'sinatrarb@googlegroups.com'
  s.homepage          = 'http://sinatrarb.com/'
  s.license           = 'MIT'
  s.files             = Dir['README*.md', 'lib/**/*', 'examples/*'] + [
    '.yardopts',
    'AUTHORS.md',
    'CHANGELOG.md',
    'CONTRIBUTING.md',
    'Gemfile',
    'LICENSE',
    'MAINTENANCE.md',
    'Rakefile',
    'SECURITY.md',
    'sinatra.gemspec',
    'VERSION'
  ]
  s.extra_rdoc_files  = %w[README.md LICENSE]
  s.rdoc_options      = %w[--line-numbers --title Sinatra --main README.rdoc --encoding=UTF-8]

  unless s.respond_to?(:metadata)
    raise <<-WARN
RubyGems 2.0 or newer is required to protect against public gem pushes. You can update your rubygems version by running:
  gem install rubygems-update
  update_rubygems:
  gem update --system
    WARN
  end

  s.metadata = {
    'source_code_uri' => 'https://github.com/sinatra/sinatra',
    'changelog_uri' => 'https://github.com/sinatra/sinatra/blob/main/CHANGELOG.md',
    'homepage_uri' => 'http://sinatrarb.com/',
    'bug_tracker_uri' => 'https://github.com/sinatra/sinatra/issues',
    'mailing_list_uri' => 'http://groups.google.com/group/sinatrarb',
    'documentation_uri' => 'https://www.rubydoc.info/gems/sinatra'
  }

  s.required_ruby_version = '>= 2.6.0'

  s.add_dependency 'mustermann', '~> 3.0'
  s.add_dependency 'rack', '~> 2.2', '>= 2.2.4'
  s.add_dependency 'rack-protection', version
  s.add_dependency 'tilt', '~> 2.0'

  s.add_development_dependency 'rack-test', '~> 2'
end
