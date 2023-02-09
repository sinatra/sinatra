require File.expand_path('integration_helper', __dir__)

module IntegrationAsyncHelper
  def it(message, &block)
    base_port = 5100 + Process.pid % 100

    %w(rainbows puma).each_with_index do |server_name, index|
      server = IntegrationHelper::BaseServer.new(server_name, base_port + index)
      next unless server.installed?

      super("with #{server.name}: #{message}") { server.run_test(self, &block) }
    end
  end
end
