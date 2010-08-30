require File.dirname(__FILE__) + '/helper'

begin
require 'sass'

class ScssTest < Test::Unit::TestCase
  def scss_app(&block)
    mock_app {
      set :views, File.dirname(__FILE__) + '/views'
      get '/', &block
    }
    get '/'
  end

  it 'renders inline Scss strings' do
    scss_app { scss "#scss {\n  background-color: white; }\n" }
    assert ok?
    assert_equal "#scss {\n  background-color: white; }\n", body
  end

  it 'renders .scss files in views path' do
    scss_app { scss :hello }
    assert ok?
    assert_equal "#scss {\n  background-color: white; }\n", body
  end

  it 'ignores the layout option' do
    scss_app { scss :hello, :layout => :layout2 }
    assert ok?
    assert_equal "#scss {\n  background-color: white; }\n", body
  end

  it "raises error if template not found" do
    mock_app {
      get('/') { scss :no_such_template }
    }
    assert_raise(Errno::ENOENT) { get('/') }
  end

  it "passes scss options to the scss engine" do
    scss_app {
      scss "#scss {\n  background-color: white;\n  color: black\n}",
        :style => :compact
    }
    assert ok?
    assert_equal "#scss { background-color: white; color: black; }\n", body
  end

  it "passes default scss options to the scss engine" do
    mock_app {
      set :scss, {:style => :compact} # default scss style is :nested
      get '/' do
        scss "#scss {\n  background-color: white;\n  color: black;\n}"
      end
    }
    get '/'
    assert ok?
    assert_equal "#scss { background-color: white; color: black; }\n", body
  end
end

rescue
  warn "#{$!.to_s}: skipping scss tests"
end
