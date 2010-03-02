require File.dirname(__FILE__) + '/helper'
require 'less'

class LessTest < Test::Unit::TestCase
  def less_app(&block)
    mock_app {
      set :views, File.dirname(__FILE__) + '/views'
      get '/', &block
    }
    get '/'
  end

  it 'renders inline Less strings' do
    less_app { less "@white_color: #fff; #main { background-color: @white_color }"}
    assert ok?
    assert_equal "#main { background-color: #ffffff; }\n", body
  end

  it 'renders .less files in views path' do
    less_app { less :hello }
    assert ok?
    assert_equal "#main { background-color: #ffffff; }\n", body
  end

  it 'ignores the layout option' do
    less_app { less :hello, :layout => :layout2 }
    assert ok?
    assert_equal "#main { background-color: #ffffff; }\n", body
  end

  it "raises error if template not found" do
    mock_app {
      get('/') { less :no_such_template }
    }
    assert_raise(Errno::ENOENT) { get('/') }
  end
end
