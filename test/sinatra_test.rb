require_relative 'test_helper'

require 'open3'
require 'rbconfig'
require 'tempfile'

class SinatraTest < Minitest::Test
  it 'creates a new Sinatra::Base subclass on new' do
    app = Sinatra.new { get('/') { 'Hello World' } }
    assert_same Sinatra::Base, app.superclass
  end

  it "responds to #template_cache" do
    assert_kind_of Sinatra::TemplateCache, Sinatra::Base.new!.template_cache
  end

  # When sinatra is required from a library or test runner (i.e. the file
  # doing the require is not the process entrypoint), ARGV must not be
  # parsed. With -v in ARGV, OptionParser's officious --version handler
  # runs abort("...: version unknown"), which raises SystemExit and kills
  # the host process.
  it "loads via require when ARGV contains '-v' and the requirer is not $0" do
    ruby    = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name'])
    lib_dir = File.expand_path('../lib', __dir__)

    Tempfile.create(['sinatra_argv_', '.rb']) do |inner|
      inner.write(<<~RUBY)
        ARGV.replace(['-v'])
        require 'sinatra'
        puts 'sinatra-loaded-ok'
      RUBY
      inner.flush

      output, status = Open3.capture2e(ruby, '-I', lib_dir, '-e', "require #{inner.path.inspect}")

      assert status.success?,
             "child exited with #{status.inspect}; output was:\n#{output}"
      assert_includes output, 'sinatra-loaded-ok',
                      "child did not reach the post-require line; output was:\n#{output}"
    end
  end
end
