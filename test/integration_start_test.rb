require_relative "integration_start_helper"

class IntegrationStartTest < Minitest::Test
  include IntegrationStartHelper

  def test_app_start_without_rackup
    # Why we skip head versions: The Gemfile used here would have to support
    # the ENVs and we would need to bundle before starting the app
    #
    # Example from locally playing with this:
    #
    #   root@df8b1e7cb106:/app# rack_session=head BUNDLE_GEMFILE=./test/integration/gemfile_without_rackup.rb ruby ./test/integration/simple_app.rb -p 0 -s puma
    #   The git source https://github.com/rack/rack-session.git is not yet checked out. Please run `bundle install` before trying to start your application
    #
    # Using bundler/inline is an idea, but it would add to the startup time
    skip "So much work to run with rack head branch" if ENV['rack'] == 'head'
    skip "So much work to run with rack-session head branch" if ENV['rack_session'] == 'head'

    app_file = File.join(__dir__, "integration", "simple_app.rb")
    gem_file = File.join(__dir__, "integration", "gemfile_without_rackup.rb")
    command = command_for(app_file)
    env = { "BUNDLE_GEMFILE" => gem_file }

    with_process(command: command, env: env) do |process, read_io|
      assert wait_for_output(read_io, /Sinatra could not start, the required gems weren't found/)
    end
  end

  def test_classic_app_start
    app_file = File.join(__dir__, "integration", "simple_app.rb")
    command = command_for(app_file)
    with_process(command: command) do |process, read_io|
      assert wait_for_output(read_io, /Sinatra \(v.+\) has taken the stage/)
    end
  end

  def test_classic_app_with_zeitwerk
    app_file = File.join(__dir__, "integration", "zeitwerk_app.rb")
    command = command_for(app_file)
    with_process(command: command) do |process, read_io|
      assert wait_for_output(read_io, /Sinatra \(v.+\) has taken the stage/)
    end
  end
end
