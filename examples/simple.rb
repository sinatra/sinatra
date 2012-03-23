#!/usr/bin/env ruby
require 'sinatra'
get('/') { 'this is a simple app' }

get('/error') { FAIL! }
