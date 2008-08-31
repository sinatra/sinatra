require 'rubygems'
require 'mocha'

$:.unshift File.dirname(File.dirname(__FILE__)) + "/lib"

require 'sinatra'
require 'sinatra/test/spec'
