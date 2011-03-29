desc "run specs"
task(:spec) { ruby '-S rspec spec' }
task(:test => :spec)

namespace :doc do
  task :readmes do
    Dir.glob 'lib/sinatra/*.rb' do |file|
      next if file == 'lib/sinatra/contrib.rb'
      doc  = File.read(file)[/^module Sinatra\n(  #[^\n]*\n)*/m].scan(/^ *#(?!#) ?(.*)\n/).join("\n")
      file = "doc/#{file[4..-4].tr("/_", "-")}.rdoc"
      File.mkdir "doc" unless File.directory? "doc"
      puts "writing #{file}"
      File.open(file, "w") { |f| f << doc }
    end
  end

  task :all => [:readmes]
end

task :doc => 'doc:all'
