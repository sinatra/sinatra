require "rubygems"

if ENV['SWIFT']
 require 'swiftcore/swiftiplied_mongrel'
 puts "Using Swiftiplied Mongrel"
elsif ENV['EVENT']
  require 'swiftcore/evented_mongrel' 
  puts "Using Evented Mongrel"
end

require "rack"

require File.dirname(__FILE__) + '/sinatra/application'
require File.dirname(__FILE__) + '/sinatra/event_context'
require File.dirname(__FILE__) + '/sinatra/route'
require File.dirname(__FILE__) + '/sinatra/error'
require File.dirname(__FILE__) + '/sinatra/mime_types'
require File.dirname(__FILE__) + '/sinatra/core_ext'
require File.dirname(__FILE__) + '/sinatra/halt_results'
require File.dirname(__FILE__) + '/sinatra/logger'

def get(*paths, &b)
  options = Hash === paths.last ? paths.pop : {}
  paths.map { |path| Sinatra.define_route(:get, path, options, &b) }
end

def post(*paths, &b)
  options = Hash === paths.last ? paths.pop : {}
  paths.map { |path| Sinatra.define_route(:post, path, options, &b) }
end

def put(*paths, &b)
  options = Hash === paths.last ? paths.pop : {}
  paths.map { |path| Sinatra.define_route(:put, path, options, &b) }
end

def delete(*paths, &b)
  options = Hash === paths.last ? paths.pop : {}
  paths.map { |path| Sinatra.define_route(:delete, path, options, &b) }
end

def error(*codes, &b)
  raise 'You must specify a block to assciate with an error' if b.nil?
  codes.each { |code| Sinatra.define_error(code, &b) }
end

def before(*groups, &b)
  groups = [:all] if groups.empty?
  groups.each { |group| Sinatra.define_filter(:before, group, &b) }
end

def after(*groups, &b)
  groups = [:all] if groups.empty?
  groups.each { |group| Sinatra.define_filter(:after, group, &b) }
end

def mime_type(content_type, *exts)
  exts.each { |ext| Sinatra::MIME_TYPES.merge(ext.to_s, content_type) }
end

def helpers(&b)
  Sinatra::EventContext.class_eval(&b)
end

def configures(*envs)
  return if Sinatra.config[:reloading]
  yield if (envs.include?(Sinatra.config[:env]) || envs.empty?)
end
alias :configure :configures

Sinatra.setup_default_events!

at_exit do
  raise $! if $!
  Sinatra.setup_logger
  
  #TODO:  Move this into command line options
  if ARGV.include?('-i')
    require File.dirname(__FILE__) + '/sinatra/irb'
  end
  
  Sinatra.run if Sinatra.config[:run]
end