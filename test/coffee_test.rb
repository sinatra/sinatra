require File.dirname(__FILE__) + '/helper'

begin
require 'coffee-script'

class CoffeeTest < Test::Unit::TestCase
  def coffee_app(&block)
    mock_app {
      set :views, File.dirname(__FILE__) + '/views'
      get '/', &block
    }
    get '/'
  end

  it 'renders inline Coffee strings' do
    coffee_app { coffee "alert 'Aye!'\n" }
    assert ok?
    assert_equal "(function() {\n  alert('Aye!');\n})();\n", body
  end

  it 'renders .coffee files in views path' do
    coffee_app { coffee :hello }
    assert ok?
    assert_equal "(function() {\n  alert(\"Aye!\");\n})();\n", body
  end

  it 'ignores the layout option' do
    coffee_app { coffee :hello, :layout => :layout2 }
    assert ok?
    assert_equal "(function() {\n  alert(\"Aye!\");\n})();\n", body
  end

  it "raises error if template not found" do
    mock_app {
      get('/') { coffee :no_such_template }
    }
    assert_raise(Errno::ENOENT) { get('/') }
  end

  it "passes coffee options to the coffee engine" do
    coffee_app {
      coffee "alert 'Aye!'\n",
        :no_wrap => true
    }
    assert ok?
    assert_equal "alert('Aye!');", body
  end

  it "passes default coffee options to the coffee engine" do
    mock_app {
      set :coffee, :no_wrap => true # default coffee style is :nested
      get '/' do
        coffee "alert 'Aye!'\n"
      end
    }
    get '/'
    assert ok?
    assert_equal "alert('Aye!');", body
  end
end

rescue
  warn "#{$!.to_s}: skipping coffee tests"
end
