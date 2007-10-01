require File.dirname(__FILE__) + '/lib/erb'

Sinatra::EventContext.send(:include, Sinatra::Erb::EventContext)
