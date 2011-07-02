$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)

desc "run specs"
task(:spec) { ruby '-S rspec spec' }
task(:test => :spec)

namespace :doc do
  task :readmes do
    Dir.glob 'lib/sinatra/*.rb' do |file|
      excluded_files = %w[lib/sinatra/contrib.rb lib/sinatra/capture.rb lib/sinatra/engine_tracking.rb]
      next if excluded_files.include?(file)
      doc  = File.read(file)[/^module Sinatra\n(  #[^\n]*\n)*/m].scan(/^ *#(?!#) ?(.*)\n/).join("\n")
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
  require 'sinatra/contrib/version'
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
