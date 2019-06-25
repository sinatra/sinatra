#!/usr/bin/env ruby -I ../lib -I lib
# frozen_string_literal: true

require 'sinatra'
get('/') { 'this is a simple app' }
