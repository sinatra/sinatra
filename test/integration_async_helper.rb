require File.expand_path('integration_helper', __dir__)

module IntegrationAsyncHelper
  Server = IntegrationHelper::BaseServer

  def it(message, &block)
    Server.all_async.each do |server|
      next unless server.installed?
      super("with #{server.name}: #{message}") { server.run_test(self, &block) }
    end
  end

  def self.extend_object(obj)
    super

    base_port = 5100 + Process.pid % 100
    servers = %w(puma)

    servers.each_with_index do |server, index|
      Server.run(server, base_port+index, async: true)
    end
  end
end
