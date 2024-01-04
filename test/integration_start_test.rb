require_relative "integration_start_helper"

class IntegrationStartTest < Minitest::Test
  include IntegrationStartHelper

  def test_app_start_without_rackup
    skip "So much work to run with rack head branch" if ENV['rack'] == 'head'

    app_file = File.join(__dir__, "integration", "simple_app.rb")
    gem_file = File.join(__dir__, "integration", "gemfile_without_rackup.rb")
    command = command_for(app_file)
    env = { "BUNDLE_GEMFILE" => gem_file }

    with_process(command: command, env: env) do |process, read_io|
      assert wait_for_output(read_io, /Sinatra could not start, the "rackup" gem was not found/)
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
