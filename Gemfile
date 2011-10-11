# Why use bundler?
# Well, not all development dependencies install on all rubies. Moreover, `gem 
# install sinatra --development` doesn't work, as it will also try to install
# development dependencies of our dependencies, and those are not conflict free.
# So, here we are, `bundle install`.
#
# If you have issues with a gem: `bundle install --without-coffee-script`.

RUBY_ENGINE = 'ruby' unless defined? RUBY_ENGINE
source :rubygems unless ENV['QUICK']

gem 'rake', '~> 0.8.7'
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
  dep ||= '~> 1.1.0' if lib == 'rack' and RUBY_VERSION == '1.8.6'
  gem lib, dep
end

gem 'haml', '~> 3.0.0', :group => 'haml'
gem 'builder', :group => 'builder'
gem 'erubis', :group => 'erubis'
gem 'less', '~> 1.0', :group => 'less'
gem 'liquid', :group => 'liquid'
gem 'slim', :group => 'slim'
gem 'RedCloth', :group => 'redcloth' if RUBY_VERSION < "1.9.3" and RUBY_ENGINE != 'macruby'

if RUBY_VERSION > '1.8.6'
  if RUBY_ENGINE == 'jruby'
    gem 'nokogiri', '!= 1.5.0'
  elsif RUBY_ENGINE != 'maglev'
    gem 'nokogiri'
  end
  gem 'coffee-script', '>= 2.0', :group => 'coffee-script'
  gem 'rdoc', '< 3.10', :group => 'rdoc'
end

platforms :ruby do
  gem 'rdiscount', :group => 'rdiscount'
end

platforms :ruby_18, :jruby do
  gem 'json', :group => 'coffee-script'
  gem 'markaby', :group => 'markaby'
  gem 'radius', :group => 'radius'
end

platforms :mri_18 do
  # bundler platforms are broken
  next unless RUBY_ENGINE == 'ruby'
  gem 'rcov', :group => 'rcov'
end
