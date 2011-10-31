libdir = File.dirname(__FILE__)
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

require 'sinatra/base'
require 'sinatra/main'

Sinatra::Application.enable :inline_templates
