require_relative "integration_start_helper"

class IntegrationStartTest < Minitest::Test
  include IntegrationStartHelper

  def test_classic_app_start
    app_file = File.join(__dir__, "integration", "simple_app.rb")
    command = command_for(app_file)
    with_process(command) do |process, read_io|
      echo_output(read_io) if debug? # will block
      assert wait_for_output(read_io, /Sinatra \(v.+\) has taken the stage/)
    end
  end

  def test_classic_app_with_zeitwerk
    app_file = File.join(__dir__, "integration", "zeitwerk_app.rb")
    command = command_for(app_file)
    with_process(command) do |process, read_io|
      echo_output(read_io) if debug? # will block
      assert wait_for_output(read_io, /Sinatra \(v.+\) has taken the stage/)
    end
  end
end
