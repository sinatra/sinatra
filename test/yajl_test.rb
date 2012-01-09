require File.expand_path('../helper', __FILE__)

begin
require 'yajl'
  
class YajlTest < Test::Unit::TestCase  
  def yajl_app(&block)
    mock_app {
      set :views, File.dirname(__FILE__) + '/views'
      get '/', &block
    }
    get '/'
  end
    
end

rescue LoadError
  warn "#{$!.to_s}: skipping yajl tests"
end  
