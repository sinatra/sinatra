require_relative 'test_helper'

begin
require 'sass-embedded'

class SassTest < Minitest::Test
  def sass_app(options = {}, &block)
    mock_app do
      set :views, __dir__ + '/views'
      set options
      get('/', &block)
    end
    get '/'
  end

  it 'renders inline Sass strings' do
    sass_app { sass "#sass\n  background-color: white\n" }
    assert ok?
    assert_equal "#sass {\n  background-color: white;\n}", body
  end

  it 'defaults content type to css' do
    sass_app { sass "#sass\n  background-color: white\n" }
    assert ok?
    assert_equal "text/css;charset=utf-8", response['Content-Type']
  end

  it 'defaults allows setting content type per route' do
    sass_app do
      content_type :html
      sass "#sass\n  background-color: white\n"
    end
    assert ok?
    assert_equal "text/html;charset=utf-8", response['Content-Type']
  end

  it 'defaults allows setting content type globally' do
    sass_app(:sass => { :content_type => 'html' }) {
      sass "#sass\n  background-color: white\n"
    }
    assert ok?
    assert_equal "text/html;charset=utf-8", response['Content-Type']
  end

  it 'renders .sass files in views path' do
    sass_app { sass :hello }
    assert ok?
    assert_equal "#sass {\n  background-color: white;\n}", body
  end

  it 'ignores the layout option' do
    sass_app { sass :hello, :layout => :layout2 }
    assert ok?
    assert_equal "#sass {\n  background-color: white;\n}", body
  end

  it "raises error if template not found" do
    mock_app { get('/') { sass :no_such_template } }
    assert_raises(Errno::ENOENT) { get('/') }
  end

  it "passes SASS options to the Sass engine" do
    sass_app do
      sass(
        "#sass\n  background-color: white\n  color: black\n",
        :style => :compressed
      )
    end
    assert ok?
    assert_equal("#sass{background-color:#fff;color:#000}", body)
  end

  it "passes default SASS options to the Sass engine" do
    mock_app do
      set :sass, {:style => :compressed} # default Sass style is :expanded
      get('/') { sass("#sass\n  background-color: white\n  color: black\n") }
    end
    get '/'
    assert ok?
    assert_equal "#sass{background-color:#fff;color:#000}", body
  end
end

rescue LoadError
  warn "#{$!}: skipping sass tests"
end
