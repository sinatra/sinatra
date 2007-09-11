require File.dirname(__FILE__) + '/lib/responder'

Sinatra::EventContext.send(:include, Sinatra::Responder)
Sinatra::Event.send(:include, Sinatra::EventResponder)
Sinatra::EventManager.send(:extend, Sinatra::DispatcherResponder)
