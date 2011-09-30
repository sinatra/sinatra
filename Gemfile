# Why use bundler?
# Well, not all development dependencies install on all rubies. Moreover, `gem
# install sinatra --development` doesn't work, as it will also try to install
# development dependencies of our dependencies, and those are not conflict free.
# So, here we are, `bundle install`.
#
# If you have issues with a gem: `bundle install --without-coffee-script`.

RUBY_ENGINE = 'ruby' unless defined? RUBY_ENGINE
source :rubygems unless ENV['QUICK']
gemspec

gem 'rake'
gem 'rack-test', '>= 0.5.6'
gem 'ci_reporter', :group => :ci

# Allows stuff like `tilt=1.2.2 bundle install` or `tilt=master ...`.
# Used by the CI.
github = "git://github.com/%s.git"
repos = { 'tilt' => github % "rtomayko/tilt", 'rack' => github % "rack/rack" }
%w[tilt rack].each do |lib|
  dep = (ENV[lib] || 'stable').sub "#{lib}-", ''
  dep = nil if dep == 'stable'
  dep = {:git => repos[lib], :branch => dep} if dep and dep !~ /(\d+\.)+\d+/
  gem lib, dep
end

gem 'haml', '>= 3.0'
gem 'sass'
gem 'builder'
gem 'erubis'
gem 'less', '~> 2.0'
gem 'liquid'
gem 'slim', '~> 1.0'
gem 'temple', '!= 0.3.3'
gem 'RedCloth' if RUBY_VERSION < "1.9.3" and not RUBY_ENGINE.start_with? 'ma'
gem 'coffee-script', '>= 2.0'
gem 'rdoc'
gem 'kramdown'
gem 'maruku'
gem 'creole'

if RUBY_ENGINE == 'jruby'
  gem 'nokogiri', '!= 1.5.0'
  gem 'jruby-openssl'
else
  gem 'nokogiri'
end

unless RUBY_ENGINE == 'jruby' && JRUBY_VERSION < "1.6.1" && !ENV['TRAVIS']
  # C extensions
  gem 'rdiscount'
  gem 'redcarpet'

  ## bluecloth is broken
  #gem 'bluecloth'
end

platforms :ruby_18, :jruby do
  gem 'json'
  gem 'markaby'
  gem 'radius'
end

platforms :mri_18 do
  # bundler platforms are broken
  next if RUBY_ENGINE != 'ruby' or RUBY_VERSION > "1.8"
  gem 'rcov'
end
