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

# Load the gemspec using the same limitations as github
def spec
  @spec ||=
    begin
      require 'rubygems/specification'
      data = File.read('sinatra.gemspec')
      spec = nil
      Thread.new { spec = eval("$SAFE = 3\n#{data}") }.join
      spec
    end
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

# Rubyforge Release / Publish Tasks ==================================

desc 'Publish API docs to rubyforge'
task 'publish:doc' => 'doc/api/index.html' do
  sh 'scp -rp doc/* rubyforge.org:/var/www/gforge-projects/sinatra/'
end

task 'publish:gem' => [package('.gem'), package('.tar.gz')] do |t|
  sh <<-end
    rubyforge add_release sinatra sinatra #{spec.version} #{package('.gem')} &&
    rubyforge add_file    sinatra sinatra #{spec.version} #{package('.tar.gz')}
  end
end

# Gemspec Helpers ====================================================

file 'sinatra.gemspec' => FileList['{lib,test,images}/**','Rakefile'] do |f|
  # read spec file and split out manifest section
  spec = File.read(f.name)
  parts = spec.split("  # = MANIFEST =\n")
  fail 'bad spec' if parts.length != 3
  # determine file list from git ls-files
  files = `git ls-files`.
    split("\n").
    sort.
    reject{ |file| file =~ /^\./ }.
    map{ |file| "    #{file}" }.
    join("\n")
  # piece file back together and write...
  parts[1] = "  s.files = %w[\n#{files}\n  ]\n"
  spec = parts.join("  # = MANIFEST =\n")
  File.open(f.name, 'w') { |io| io.write(spec) }
  puts "updated #{f.name}"
end

# Hanna RDoc =========================================================
#
# Building docs requires the hanna gem:
#   gem install mislav-hanna --source=http://gems.github.com

desc 'Generate Hanna RDoc under doc/api'
task :doc => ['doc/api/index.html']

file 'doc/api/index.html' => FileList['lib/**/*.rb','README.rdoc'] do |f|
  rb_files = f.prerequisites
  sh((<<-end).gsub(/\s+/, ' '))
    hanna --charset utf8 \
          --fmt html \
          --inline-source \
          --line-numbers \
          --main README.rdoc \
          --op doc/api \
          --title 'Sinatra API Documentation' \
          #{rb_files.join(' ')}
  end
end
CLEAN.include 'doc/api'
