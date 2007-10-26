require File.dirname(__FILE__) + '/methods'

module Sinatra
  module Test
    module Spec
      def self.included(base)
        require File.dirname(__FILE__) + '/../../sinatra'
        require 'test/spec'
        Server.running = true
        Options.set_environment :test
        Environment.prepare_loggers
      end
    end
  end
end

include Sinatra::Test::Spec

class Test::Spec::TestCase
  
  module InstanceMethods
    include Sinatra::Test::Methods
  end
  
  alias :initialize_orig :initialize
  
  def initialize(name, parent=nil, superclass=Test::Unit::TestCase)
    initialize_orig(name, parent, superclass)
    
    @testcase.setup do
      Sinatra::EventManager.reset!
      Sinatra::Event.reset!
    end
  end
end
