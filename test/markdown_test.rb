require File.dirname(__FILE__) + '/helper'

MarkdownTest = proc do
  def markdown_app(&block)
    mock_app do
      set :views, File.dirname(__FILE__) + '/views'
      get '/', &block
    end
    get '/'
  end

  def assert_like(a,b)
    pattern = /\s*\n\s*| id=['"][^"']*["']/
    assert_equal a.strip.gsub(pattern, ""), b.strip.gsub(pattern, "")
  end

  def setup
    Tilt.prefer engine, 'markdown', 'mkd', 'md'
    super
  end

  it 'uses the correct engine' do
    assert_equal engine, Tilt[:md]
    assert_equal engine, Tilt[:mkd]
    assert_equal engine, Tilt[:markdown]
  end

  it 'renders inline markdown strings' do
    markdown_app { markdown '# Hiya' }
    assert ok?
    assert_like "<h1>Hiya</h1>\n", body
  end

  it 'renders .markdown files in views path' do
    markdown_app { markdown :hello }
    assert ok?
    assert_like "<h1>Hello From Markdown</h1>", body
  end

  it "raises error if template not found" do
    mock_app { get('/') { markdown :no_such_template } }
    assert_raise(Errno::ENOENT) { get('/') }
  end
end

# Will generate RDiscountTest, KramdownTest, etc.
Tilt.mappings['md'].each do |t|
  begin
    t.new { "" }
    klass = Class.new(Test::Unit::TestCase) { define_method(:engine) { t }}
    klass.class_eval(&MarkdownTest)
    Object.const_set t.name[/[^:]+(?=Template$)/] << "Test", klass
  rescue LoadError
    warn "#{$!}: skipping markdown tests with #{t}"
  end
end
