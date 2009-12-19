libdir = File.dirname(__FILE__)
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

require 'sinatra/base'
require 'sinatra/main'

use_in_file_templates!
