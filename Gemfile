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
gem 'sass' if RUBY_VERSION < "2.0"
gem 'builder'
gem 'erubis'
gem 'liquid' unless RUBY_ENGINE == 'rbx' and RUBY_VERSION > '1.9'
gem 'slim', '~> 1.0'
gem 'temple', '!= 0.3.3'
gem 'coffee-script', '>= 2.0'
gem 'rdoc'
gem 'kramdown'
gem 'maruku'
gem 'creole'
gem 'markaby'
gem 'radius'

if RUBY_ENGINE == 'jruby'
  gem 'nokogiri', '!= 1.5.0'
  gem 'jruby-openssl'
  gem 'trinidad'
else
  gem 'yajl-ruby'
  gem 'nokogiri'
  gem 'thin'
end

if RUBY_ENGINE == "ruby" and RUBY_VERSION > '1.9'
  gem 'less', '~> 2.0'
else
  gem 'less', '~> 1.0'
end

if RUBY_ENGINE != 'jruby' or not ENV['TRAVIS']
  # C extensions
  gem 'rdiscount'
  platforms(:ruby_18) do
    gem 'redcarpet'
    gem 'mongrel'
  end
  gem 'RedCloth' unless RUBY_ENGINE == "macruby"
  gem 'puma'

  ## bluecloth is broken
  #gem 'bluecloth'
end

gem 'net-http-server'

platforms :ruby_18, :jruby do
  gem 'json' unless RUBY_VERSION > '1.9' # is there a jruby but 1.8 only selector?
end

platforms :mri_18 do
  # bundler platforms are broken
  next if RUBY_ENGINE != 'ruby' or RUBY_VERSION > "1.8"
  gem 'rcov'
end
