source "http://rubygems.org"
if RUBY_VERSION =~ /1.9/
	Encoding.default_external = Encoding::UTF_8
	Encoding.default_internal = Encoding::UTF_8
end

gem 'rake'

rack_version = ENV['rack'].to_s
rack_version = nil if rack_version.empty? or rack_version == 'stable'
rack_version = {:github => 'rack/rack'} if rack_version == 'master'
gem 'rack', rack_version

gemspec
