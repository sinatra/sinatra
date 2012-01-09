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
repos  = {'tilt' => github % "rtomayko/tilt", 'rack' => github % "rack/rack"}

%w[tilt rack].each do |lib|
  dep = case ENV[lib]
        when 'stable', nil then nil
        when /(\d+\.)+\d+/ then "~> " + ENV[lib].sub("#{lib}-", '')
        else {:git => repos[lib], :branch => dep}
        end
  gem lib, dep
end

gem 'haml', '>= 3.0'
gem 'sass'
gem 'builder'
gem 'erubis'
gem 'liquid'
gem 'slim', '~> 1.0'
gem 'temple', '!= 0.3.3'
gem 'coffee-script', '>= 2.0'
gem 'rdoc'
gem 'kramdown'
gem 'maruku'
gem 'creole'
gem 'markaby'
gem 'radius'
gem 'yajl-ruby'

if RUBY_ENGINE == 'jruby'
  gem 'nokogiri', '!= 1.5.0'
  gem 'jruby-openssl'
else
  gem 'nokogiri'
end

if RUBY_ENGINE == "ruby"
  gem 'less', '~> 2.0'
else
  gem 'less', '~> 1.0'
end

unless RUBY_ENGINE == 'jruby' && JRUBY_VERSION < "1.6.1" && !ENV['TRAVIS']
  # C extensions
  gem 'rdiscount'
  platforms(:ruby_18) { gem 'redcarpet' }
  gem 'RedCloth' unless RUBY_ENGINE == "macruby"

  ## bluecloth is broken
  #gem 'bluecloth'
end

platforms :ruby_18, :jruby do
  gem 'json'
end

platforms :mri_18 do
  # bundler platforms are broken
  next if RUBY_ENGINE != 'ruby' or RUBY_VERSION > "1.8"
  gem 'rcov'
end
