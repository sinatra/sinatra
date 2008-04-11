require 'rubygems'
require 'rake/testtask'
require 'rake/rdoctask'
require 'echoe'

task :default => :test

Rake::RDocTask.new do |rd|
  rd.main = "README.rdoc"
  rd.rdoc_files += ["README.rdoc"]
  rd.rdoc_files += Dir.glob("lib/**/*.rb")
  rd.rdoc_dir = 'doc'
end

Rake::TestTask.new do |t|
  ENV['SINATRA_ENV'] = 'test'
  t.pattern = File.dirname(__FILE__) + "/test/*_test.rb"
end

Echoe.new("sinatra") do |p|
  p.author = "Blake Mizerany"
  p.summary = "Classy web-development dressed in a DSL"
  p.url = "http://www.sinatrarb.com"
  p.docs_host = "sinatrarb.com:/var/www/blakemizerany.com/public/docs/"
  p.dependencies = ["mongrel >=1.0.1", "rack >= 0.3.0"]
  p.install_message = "*** Be sure to checkout the site for helpful tips!  sinatrarb.com ***"
  p.include_rakefile = true
end

