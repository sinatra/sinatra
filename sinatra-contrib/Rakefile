require "rake/testtask"

begin
  require "hanna/rdoctask"
rescue LoadError
  require "rake/rdoctask"
end

begin
  require "metric_fu"
rescue LoadError
end

begin
  require "mg"
  MG.new("sinatra-content-for.gemspec")
rescue LoadError
end

desc "Default: run all tests"
task :default => :test

desc "Run library tests"
Rake::TestTask.new do |t|
  t.test_files = FileList['test/**/*_test.rb']
end

Rake::RDocTask.new do |rd|
  rd.main = "README"
  rd.title = "Documentation for ContentFor"
  rd.rdoc_files.include("README.rdoc", "LICENSE", "lib/**/*.rb")
  rd.rdoc_dir = "doc"
end
