require File.dirname(__FILE__) + '/lib/haml'

Sinatra::EventContext.send(:include, Sinatra::Haml::EventContext)
