require_relative 'test_helper'

MarkdownTest = proc do
  def markdown_app(&block)
    mock_app do
      set :views, __dir__ + '/views'
      get('/', &block)
    end
    get '/'
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
    assert_raises(Errno::ENOENT) { get('/') }
  end

  it "renders with inline layouts" do
    mock_app do
      layout { 'THIS. IS. #{yield.upcase}!' }
      get('/') { markdown 'Sparta', :layout_engine => :str }
    end
    get '/'
    assert ok?
    assert_like 'THIS. IS. <P>SPARTA</P>!', body
  end

  it "renders with file layouts" do
    markdown_app {
      markdown 'Hello World', :layout => :layout2, :layout_engine => :erb
    }
    assert ok?
    assert_body "ERB Layout!\n<p>Hello World</p>"
  end

  it "can be used in a nested fashion for partials and whatnot" do
    mock_app do
      template(:inner) { "hi" }
      template(:outer) { "<outer><%= markdown :inner %></outer>" }
      get('/') { erb :outer }
    end

    get '/'
    assert ok?
    assert_like '<outer><p>hi</p></outer>', body
  end
end

[
  "Tilt::PandocTemplate",
  "Tilt::CommonMarkerTemplate",
  "Tilt::KramdownTemplate",
  "Tilt::RedcarpetTemplate",
  "Tilt::RDiscountTemplate"
].each do |template_name|
  begin
    template = Object.const_get(template_name)

    klass = Class.new(Minitest::Test) { define_method(:engine) { template } }
    klass.class_eval(&MarkdownTest)

    name = template_name.split('::').last.sub(/Template$/, 'Test')
    Object.const_set name, klass
  rescue LoadError, NameError
    warn "#{$!}: skipping markdown tests with #{template_name}"
  end
end
