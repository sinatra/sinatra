# Why use bundler?
# Well, not all development dependencies install on all rubies. Moreover, `gem
# install sinatra --development` doesn't work, as it will also try to install
# development dependencies of our dependencies, and those are not conflict free.
# So, here we are, `bundle install`.
#
# If you have issues with a gem: `bundle install --without-coffee-script`.

RUBY_ENGINE = 'ruby' unless defined? RUBY_ENGINE
source 'https://rubygems.org' unless ENV['QUICK']
gemspec

gem 'rake'
gem 'rack', github: 'rack/rack'
gem 'rack-test', '>= 0.6.2'
gem "minitest", "~> 5.0"
gem 'tool', '~> 0.2'

if RUBY_ENGINE == 'jruby'
  gem 'nokogiri', '!= 1.5.0'
  gem 'trinidad'
end

if RUBY_ENGINE == "ruby"
  gem 'less', '~> 2.0'
  gem 'therubyracer'
  gem 'redcarpet'
  gem 'wlang', '>= 2.0.1'
  gem 'bluecloth'
  gem 'rdiscount'
  gem 'RedCloth'
  gem 'puma'
  #TODO: remove explicit require once net-http-server does it
  #(apparently it was shipped w/ stdlib in Rubies < 2.2.2)
  gem 'gserver'
  gem 'net-http-server'
  gem 'yajl-ruby'
  gem 'nokogiri'
  gem 'thin'
  gem 'slim', '~> 2.0'
  gem 'coffee-script', '>= 2.0'
  gem 'rdoc'
  gem 'kramdown'
  gem 'maruku'
  gem 'creole'
  gem 'wikicloth'
  gem 'markaby'
  gem 'radius'
  gem 'asciidoctor'
  gem 'liquid'
  gem 'stylus'
  gem 'rabl'
  gem 'builder'
  gem 'erubis'
  gem 'haml', '>= 3.0'
  gem 'sass'
  gem 'reel-rack'
end

if RUBY_ENGINE == "rbx"
  gem 'json'
  gem 'rubysl'
  gem 'rubysl-test-unit'
end

platforms :jruby do
  gem 'json'
end
