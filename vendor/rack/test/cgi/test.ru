#!/usr/local/bin/ruby ../../bin/rackup
#\ -E deployment -I ~/projects/rack/lib
# -*- ruby -*-

require '../testrequest'

run TestRequest.new
