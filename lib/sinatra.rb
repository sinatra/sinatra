$LOAD_PATH.unshift File.dirname(__FILE__)
require 'sinatra/base'
require 'sinatra/main'
require 'sinatra/compat'

use_in_file_templates!
