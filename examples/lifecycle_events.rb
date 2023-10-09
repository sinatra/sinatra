#!/usr/bin/env ruby -I ../lib -I lib
# frozen_string_literal: true

require 'sinatra'

get('/') do
  'This shows how lifecycle events work'
end

on_start do
  puts "=============="
  puts "  Booting up"
  puts "=============="
end

on_stop do
  puts "================="
  puts "  Shutting down"
  puts "================="
end
