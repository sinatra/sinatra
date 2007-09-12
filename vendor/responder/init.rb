require File.dirname(__FILE__) + '/lib/responder'

Sinatra::EventContext.send(:include, Sinatra::Responder)
