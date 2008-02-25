require 'rubygems'
require 'rake/testtask'

task :default => :test

Rake::TestTask.new do |t|
  ENV['SINATRA_ENV'] = 'test'
  t.pattern = File.dirname(__FILE__) + "/test/*_test.rb"
end
