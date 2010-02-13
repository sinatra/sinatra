require 'rake/clean'
require 'rake/testtask'
require 'fileutils'

task :default => :test
task :spec => :test

def source_version
  line = File.read('lib/sinatra/base.rb')[/^\s*VERSION = .*/]
  line.match(/.*VERSION = '(.*)'/)[1]
end

# SPECS ===============================================================

Rake::TestTask.new(:test) do |t|
  t.test_files = FileList['test/*_test.rb']
  t.ruby_opts = ['-rubygems -I.'] if defined? Gem
end

# Rcov ================================================================
namespace :test do
  desc 'Mesures test coverage'
  task :coverage do
    rm_f "coverage"
    rcov = "rcov --text-summary --test-unit-only -Ilib"
    system("#{rcov} --no-html --no-color test/*_test.rb")
  end
end

# Website =============================================================
# Building docs requires HAML and the hanna gem:
#   gem install mislav-hanna --source=http://gems.github.com

desc 'Generate RDoc under doc/api'
task 'doc'     => ['doc:api']

task 'doc:api' => ['doc/api/index.html']

file 'doc/api/index.html' => FileList['lib/**/*.rb','README.rdoc'] do |f|
  require 'rbconfig'
  hanna = RbConfig::CONFIG['ruby_install_name'].sub('ruby', 'hanna')
  rb_files = f.prerequisites
  sh((<<-end).gsub(/\s+/, ' '))
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

# PACKAGING ============================================================

if defined?(Gem)
  # Load the gemspec using the same limitations as github
  def spec
    require 'rubygems' unless defined? Gem::Specification
    @spec ||= eval(File.read('sinatra.gemspec'))
  end

  def package(ext='')
    "pkg/sinatra-#{spec.version}" + ext
  end

  desc 'Build packages'
  task :package => %w[.gem .tar.gz].map {|e| package(e)}

  desc 'Build and install as local gem'
  task :install => package('.gem') do
    sh "gem install #{package('.gem')}"
  end

  directory 'pkg/'
  CLOBBER.include('pkg')

  file package('.gem') => %w[pkg/ sinatra.gemspec] + spec.files do |f|
    sh "gem build sinatra.gemspec"
    mv File.basename(f.name), f.name
  end

  file package('.tar.gz') => %w[pkg/] + spec.files do |f|
    sh <<-SH
      git archive \
        --prefix=sinatra-#{source_version}/ \
        --format=tar \
        HEAD | gzip > #{f.name}
    SH
  end

  task 'sinatra.gemspec' => FileList['{lib,test,compat}/**','Rakefile','CHANGES','*.rdoc'] do |f|
    # read spec file and split out manifest section
    spec = File.read(f.name)
    head, manifest, tail = spec.split("  # = MANIFEST =\n")
    # replace version and date
    head.sub!(/\.version = '.*'/, ".version = '#{source_version}'")
    head.sub!(/\.date = '.*'/, ".date = '#{Date.today.to_s}'")
    # determine file list from git ls-files
    files = `git ls-files`.
      split("\n").
      sort.
      reject{ |file| file =~ /^\./ }.
      reject { |file| file =~ /^doc/ }.
      map{ |file| "    #{file}" }.
      join("\n")
    # piece file back together and write...
    manifest = "  s.files = %w[\n#{files}\n  ]\n"
    spec = [head,manifest,tail].join("  # = MANIFEST =\n")
    File.open(f.name, 'w') { |io| io.write(spec) }
    puts "updated #{f.name}"
  end
end
