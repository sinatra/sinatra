require 'rake/clean'
require 'rake/testtask'
require 'fileutils'
require 'date'
require 'bundler'

Bundler::GemHelper.install_tasks

task :default => :test
task :spec => :test

def source_version
  line = File.read('lib/sinatra/base.rb')[/^\s*VERSION = .*/]
  line.match(/.*VERSION = '(.*)'/)[1]
end

# SPECS ===============================================================

if !ENV['NO_TEST_FIX'] and RUBY_VERSION == '1.9.2' and RUBY_PATCHLEVEL == 0
  # Avoids seg fault
  task(:test) do
    second_run  = %w[settings rdoc markaby templates static textile].map { |l| "test/#{l}_test.rb" }
    first_run   = Dir.glob('test/*_test.rb') - second_run
    [first_run, second_run].each { |f| sh "testrb #{f.join ' '}" }
  end
else
  Rake::TestTask.new(:test) do |t|
    t.test_files = FileList['test/*_test.rb']
    t.ruby_opts = ['-rubygems'] if defined? Gem
    t.ruby_opts << '-I.'
  end
end

# Rcov ================================================================
namespace :test do
  desc 'Mesures test coverage'
  task :coverage do
    rm_f "coverage"
    rcov = "rcov --text-summary -Ilib"
    system("#{rcov} --no-html --no-color test/*_test.rb")
  end
end

# Website =============================================================
# Building docs requires HAML and the hanna gem:
#   gem install mislav-hanna --source=http://gems.github.com

desc 'Generate RDoc under doc/api'
task 'doc'     => ['doc:api']

task 'doc:api' => ['doc/api/index.html']

file 'doc/api/index.html' => FileList['lib/**/*.rb', 'README.*'] do |f|
  require 'rbconfig'
  hanna = RbConfig::CONFIG['ruby_install_name'].sub('ruby', 'hanna')
  rb_files = f.prerequisites
  sh(<<-end.gsub(/\s+/, ' '))
    #{hanna}
      --charset utf8
      --fmt html
      --inline-source
      --line-numbers
      --main README.rdoc
      --op doc/api
      --title 'Sinatra API Documentation'
      #{rb_files.join(' ')}
  end
end
CLEAN.include 'doc/api'
