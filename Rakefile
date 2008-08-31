require 'rake/clean'

task :default => :test

# SPECS ===============================================================

desc 'Run specs with story style output'
task :spec do
  sh 'specrb --specdox -Ilib:test test/*_test.rb'
end

desc 'Run specs with unit test style output'
task :test => FileList['test/*_test.rb'] do |t|
  suite = t.prerequisites.map{|f| "-r#{f.chomp('.rb')}"}.join(' ')
  sh "ruby -Ilib:test #{suite} -e ''", :verbose => false
end

# PACKAGING ============================================================

def spec
  @spec ||=
    eval(File.read('sinatra.gemspec'))
end

def package(ext='')
  "dist/sinatra-#{spec.version}" + ext
end

desc 'Build packages'
task :package => %w[.gem .tar.gz].map {|e| package(e)}

desc 'Build and install as local gem'
task :install => package('.gem') do
  sh "gem install #{package('.gem')}"
end

directory 'dist/'

file package('.gem') => %w[dist/ sinatra.gemspec] + spec.files do |f|
  sh "gem build sinatra.gemspec"
  mv File.basename(f.name), f.name
end

file package('.tar.gz') => %w[dist/] + spec.files do |f|
  sh "git archive --format=tar HEAD | gzip > #{f.name}"
end
