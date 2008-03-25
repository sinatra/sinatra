require 'rubygems'
require 'rake/testtask'
require 'rake/rdoctask'

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
