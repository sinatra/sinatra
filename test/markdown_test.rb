require File.expand_path('../helper', __FILE__)

MarkdownTest = proc do
  def markdown_app(&block)
    mock_app do
      set :views, File.dirname(__FILE__) + '/views'
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
    assert_raise(Errno::ENOENT) { get('/') }
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

# Will generate RDiscountTest, KramdownTest, etc.
if Tilt.respond_to?(:mappings)
  engines = Tilt.mappings['md'].select do |t|
    begin
      t.new { "" }
    rescue LoadError, NameError
      warn "#{$!}: skipping markdown tests with #{t}"
      nil
    end
  end.compact
else
  # NOTE: This is a private API, but it should be stable enough to use in tests.
  engines = Tilt.default_mapping.lazy_map['md'].map do |klass_name, file|
    begin
      require file
      eval(klass_name)
    rescue LoadError, NameError
      warn "#{$!}: skipping markdown tests with #{klass_name}, #{file}"
      nil
    end
  end.compact
end

engines.each do |t|
  klass = Class.new(Test::Unit::TestCase) { define_method(:engine) { t } }
  klass.class_eval(&MarkdownTest)
  name = t.name[/[^:]+$/].sub(/Template$/, '') << "Test"
  Object.const_set name, klass
end
