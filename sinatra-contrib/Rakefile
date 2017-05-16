$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'open-uri'
require 'yaml'
require 'sinatra/contrib/version'

desc "run specs"
task(:spec) { ruby '-S rspec spec -cw' }
task(:test => :spec)
task(:default => :spec)

namespace :doc do
  task :readmes do
    Dir.glob 'lib/sinatra/*.rb' do |file|
      puts "Trying file... #{file}"
      excluded_files = %w[lib/sinatra/contrib.rb lib/sinatra/decompile.rb]
      next if excluded_files.include?(file)
      doc  = File.read(file)[/^module Sinatra(\n)+(  #[^\n]*\n)*/m].scan(/^ *#(?!#) ?(.*)\n/).join("\n")
      file = "doc/#{file[4..-4].tr("/_", "-")}.rdoc"
      Dir.mkdir "doc" unless File.directory? "doc"
      puts "writing #{file}"
      File.open(file, "w") { |f| f << doc }
    end
  end

  task :index do
    doc = File.read("README.md")
    file = "doc/sinatra-contrib-readme.md"
    Dir.mkdir "doc" unless File.directory? "doc"
    puts "writing #{file}"
    File.open(file, "w") { |f| f << doc }
  end

  task :all => [:readmes, :index]
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

  File.open('sinatra-contrib.gemspec', 'w') { |f| f << content }
end

task :gemspec => 'sinatra-contrib.gemspec'

task :release => :gemspec do
  sh <<-SH
    rm -Rf sinatra-contrib*.gem &&
    gem build sinatra-contrib.gemspec &&
    gem install sinatra-contrib*.gem --local &&
    gem push sinatra-contrib*.gem  &&
    git commit --allow-empty -a -m '#{Sinatra::Contrib::VERSION} release'  &&
    git tag -s v#{Sinatra::Contrib::VERSION} -m '#{Sinatra::Contrib::VERSION} release'  &&
    git push && (git push origin master || true) &&
    git push --tags && (git push origin --tags || true)
  SH
end

