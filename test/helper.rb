require 'rubygems'
require 'mocha'

gem 'rack', '~> 0.4.0'

$:.unshift File.dirname(File.dirname(__FILE__)) + "/lib"

require 'sinatra'
require 'sinatra/test/spec'
