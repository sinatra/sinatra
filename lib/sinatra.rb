# Copyright (c) 2007 Blake Mizerany
# 
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

%w(rubygems rack).each do |library|
  begin
    require library
  rescue LoadError
    raise "== Sinatra cannot run without #{library} installed"
  end
end

SINATRA_ROOT = File.dirname(__FILE__) + '/..'

require File.dirname(__FILE__) + '/sinatra/loader'

Sinatra::Loader.load_files Dir.glob(SINATRA_ROOT + '/lib/sinatra/core_ext/*.rb')
Sinatra::Loader.load_files Dir.glob(SINATRA_ROOT + '/lib/sinatra/rack_ext/*.rb')
Sinatra::Loader.load_files Dir.glob(SINATRA_ROOT + '/lib/sinatra/*.rb')
Sinatra::Loader.load_files Dir.glob(SINATRA_ROOT + '/vendor/*/init.rb')

Sinatra::Loader.load_files Dir.glob(File.dirname($0) + '/vendor/*/init.rb')

Sinatra::Environment.prepare

at_exit do
  Sinatra::Environment.prepare_loggers unless Sinatra::Options.environment == :test
  Sinatra::Irb.start! if Sinatra::Options.console
  Sinatra::Server.new.start unless Sinatra::Server.running
end
