require 'multi_json'

require 'spec_helper'
require 'okjson'

RSpec.shared_examples_for "a json encoder" do |lib, const|
  before do
    begin
      require lib if lib
      @encoder = eval(const)
    rescue LoadError
      skip "unable to load #{lib}"
    end
  end

  it "allows setting :encoder to #{const}" do
    enc = @encoder
    mock_app { get('/') { json({'foo' => 'bar'}, :encoder => enc) }}
    results_in 'foo' => 'bar'
  end

  it "allows setting settings.json_encoder to #{const}" do
    enc = @encoder
    mock_app do
      set :json_encoder, enc
      get('/') { json 'foo' => 'bar' }
    end
    results_in 'foo' => 'bar'
  end
end

RSpec.describe Sinatra::JSON do
  def mock_app(&block)
    super do
      class_eval(&block)
    end
  end

  def results_in(obj)
    expect(OkJson.decode(get('/').body)).to eq(obj)
  end

  it "encodes objects to json out of the box" do
    mock_app { get('/') { json :foo => [1, 'bar', nil] } }
    results_in 'foo' => [1, 'bar', nil]
  end

  it 'flags the multi_json compat shim for removal once the floor reaches 1.21' do
    # multi_json 1.21.0 introduced ::MultiJSON and #generate, deprecating
    # ::MultiJson and #dump. The defined?(::MultiJSON) / respond_to?(:generate)
    # fallbacks in lib/sinatra/json.rb exist only to support multi_json < 1.21
    # (the gemspec floor). Once the floor reaches 1.21 they are dead code.
    spec = Gem::Specification.load(File.expand_path('../sinatra-contrib.gemspec', __dir__))
    dep  = spec&.dependencies&.find { |d| d.name == 'multi_json' }
    skip 'multi_json is no longer a dependency' unless dep

    # 1.20.1 is the final pre-1.21 release; if the floor no longer admits it,
    # every supported version has the new API and the shim is dead.
    expect(dep.requirement.satisfied_by?(Gem::Version.new('1.20.1'))).to be(true),
           "multi_json floor is now #{dep.requirement}; every supported version has " \
           '::MultiJSON and #generate. Drop the defined?(::MultiJSON) / ' \
           'respond_to?(:generate) fallbacks in lib/sinatra/json.rb and call ' \
           '::MultiJSON.generate directly.'
  end

  it "sets the content type to 'application/json'" do
    mock_app { get('/') { json({}) } }
    expect(get('/')["Content-Type"]).to include("application/json")
  end

  it "allows overriding content type with :content_type" do
    mock_app { get('/') { json({}, :content_type => "foo/bar") } }
    expect(get('/')["Content-Type"]).to eq("foo/bar")
  end

  it "accepts shorthands for :content_type" do
    mock_app { get('/') { json({}, :content_type => :js) } }
    # Changed to "text/javascript" in Rack >3.0
    # https://github.com/sinatra/sinatra/pull/1857#issuecomment-1445062212
    expect(get('/')["Content-Type"])
      .to eq("application/javascript;charset=utf-8").or eq("text/javascript;charset=utf-8")
  end

  it 'calls generate on :encoder if available' do
    enc = Object.new
    def enc.generate(obj) obj.inspect end
    mock_app { get('/') { json(42, :encoder => enc) }}
    expect(get('/').body).to eq('42')
  end

  it 'calls encode on :encoder if available' do
    enc = Object.new
    def enc.encode(obj) obj.inspect end
    mock_app { get('/') { json(42, :encoder => enc) }}
    expect(get('/').body).to eq('42')
  end

  it 'sends :encoder as method call if it is a Symbol' do
    mock_app { get('/') { json(42, :encoder => :inspect) }}
    expect(get('/').body).to eq('42')
  end

  it 'calls generate on settings.json_encoder if available' do
    enc = Object.new
    def enc.generate(obj) obj.inspect end
    mock_app do
      set :json_encoder, enc
      get('/') { json 42 }
    end
    expect(get('/').body).to eq('42')
  end

  it 'calls encode on settings.json_encode if available' do
    enc = Object.new
    def enc.encode(obj) obj.inspect end
    mock_app do
      set :json_encoder, enc
      get('/') { json 42 }
    end
    expect(get('/').body).to eq('42')
  end

  it 'sends settings.json_encode  as method call if it is a Symbol' do
    mock_app do
      set :json_encoder, :inspect
      get('/') { json 42 }
    end
    expect(get('/').body).to eq('42')
  end

  describe('Yajl')    { it_should_behave_like "a json encoder", "yajl", "Yajl::Encoder" } unless defined? JRUBY_VERSION
  describe('JSON')    { it_should_behave_like "a json encoder", "json", "::JSON"        }
  describe('OkJson')  { it_should_behave_like "a json encoder", nil,    "OkJson"        }
  describe('to_json') { it_should_behave_like "a json encoder", "json", ":to_json"      }
  describe('without') { it_should_behave_like "a json encoder", nil,    "Sinatra::JSON" }
end
