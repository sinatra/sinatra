$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'open-uri'
require 'yaml'
require 'sinatra/contrib/version'

desc "run specs"
task(:spec) { ruby '-S rspec spec -c' }
task(:test => :spec)
task(:default => :spec)

namespace :doc do
  task :readmes do
    Dir.glob 'lib/sinatra/*.rb' do |file|
      excluded_files = %w[lib/sinatra/contrib.rb lib/sinatra/capture.rb lib/sinatra/engine_tracking.rb]
      next if excluded_files.include?(file)
      doc  = File.read(file)[/^module Sinatra(\n)+(  #[^\n]*\n)*/m].scan(/^ *#(?!#) ?(.*)\n/).join("\n")
      file = "doc/#{file[4..-4].tr("/_", "-")}.rdoc"
      Dir.mkdir "doc" unless File.directory? "doc"
      puts "writing #{file}"
      File.open(file, "w") { |f| f << doc }
    end
  end

  task :all => [:readmes]
end

desc "generate documentation"
task :doc => 'doc:all'

desc "generate gemspec"
task 'sinatra-contrib.gemspec' do
  content = File.read 'sinatra-contrib.gemspec'

  fields = {
    :authors => `git shortlog -sn`.scan(/[^\d\s].*/),
    :email   => `git shortlog -sne`.scan(/[^<]+@[^>]+/),
    :files   => `git ls-files`.split("\n").reject { |f| f =~ /^(\.|Gemfile)/ }
  }

  fields.each do |field, values|
    updated = "  s.#{field} = ["
    updated << values.map { |v| "\n    %p" % v }.join(',')
    updated << "\n  ]"
    content.sub!(/  s\.#{field} = \[\n(    .*\n)*  \]/, updated)
  end

  content.sub! /(s\.version.*=\s+).*/, "\\1\"#{Sinatra::Contrib::VERSION}\""
  File.open('sinatra-contrib.gemspec', 'w') { |f| f << content }
end

task :gemspec => 'sinatra-contrib.gemspec'

desc 'update travis config to correspond to sinatra'
task :travis, [:branch] do |t, a|
  a.with_defaults :branch => :master
  data = YAML.load open("https://raw.github.com/sinatra/sinatra/#{a.branch}/.travis.yml")
  data["notifications"]["recipients"] << "ohhgabriel@gmail.com"
  File.open('.travis.yml', 'w') { |f| f << data.to_yaml }
  system 'git add .travis.yml && git diff --cached .travis.yml'
end

task :release => :gemspec do
  sh <<-SH
    rm -Rf sinatra-contrib*.gem &&
    gem build sinatra-contrib.gemspec &&
    gem install sinatra-contrib*.gem --local &&
    gem push sinatra-contrib*.gem  &&
    git commit --allow-empty -a -m '#{Sinatra::Contrib::VERSION} release'  &&
    git tag -s v#{Sinatra::Contrib::VERSION} -m '#{Sinatra::Contrib::VERSION} release'  &&
    git tag -s #{Sinatra::Contrib::VERSION} -m '#{Sinatra::Contrib::VERSION} release'  &&
    git push && (git push sinatra || true) &&
    git push --tags && (git push sinatra --tags || true)
  SH
end

