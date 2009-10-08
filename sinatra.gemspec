Gem::Specification.new do |s|
  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=

  s.name = 'sinatra'
  s.version = '0.10.1'
  s.date = '2009-10-08'

  s.description = "Classy web-development dressed in a DSL"
  s.summary     = "Classy web-development dressed in a DSL"

  s.authors = ["Blake Mizerany", "Ryan Tomayko", "Simon Rozet"]
  s.email = "sinatrarb@googlegroups.com"

  # = MANIFEST =
  s.files = %w[
    AUTHORS
    CHANGES
    LICENSE
    README.jp.rdoc
    README.rdoc
    Rakefile
    lib/sinatra.rb
    lib/sinatra/base.rb
    lib/sinatra/images/404.png
    lib/sinatra/images/500.png
    lib/sinatra/main.rb
    lib/sinatra/showexceptions.rb
    lib/tilt.rb
    sinatra.gemspec
    test/base_test.rb
    test/builder_test.rb
    test/contest.rb
    test/data/reload_app_file.rb
    test/erb_test.rb
    test/extensions_test.rb
    test/filter_test.rb
    test/haml_test.rb
    test/helper.rb
    test/helpers_test.rb
    test/mapped_error_test.rb
    test/middleware_test.rb
    test/options_test.rb
    test/request_test.rb
    test/response_test.rb
    test/result_test.rb
    test/route_added_hook_test.rb
    test/routing_test.rb
    test/sass_test.rb
    test/server_test.rb
    test/sinatra_test.rb
    test/static_test.rb
    test/templates_test.rb
    test/views/error.builder
    test/views/error.erb
    test/views/error.haml
    test/views/error.sass
    test/views/foo/hello.test
    test/views/hello.builder
    test/views/hello.erb
    test/views/hello.haml
    test/views/hello.sass
    test/views/hello.test
    test/views/layout2.builder
    test/views/layout2.erb
    test/views/layout2.haml
    test/views/layout2.test
  ]
  # = MANIFEST =

  s.test_files = s.files.select {|path| path =~ /^test\/.*_test.rb/}

  s.extra_rdoc_files = %w[README.rdoc LICENSE]
  s.add_dependency 'rack',    '>= 1.0'
  s.add_development_dependency 'shotgun', '>= 0.3',   '< 1.0'
  s.add_development_dependency 'rack-test', '>= 0.3.0'

  s.has_rdoc = true
  s.homepage = "http://sinatra.rubyforge.org"
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Sinatra", "--main", "README.rdoc"]
  s.require_paths = %w[lib]
  s.rubyforge_project = 'sinatra'
  s.rubygems_version = '1.1.1'
end
