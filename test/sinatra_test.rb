require File.expand_path('../helper', __FILE__)

class SinatraTest < Test::Unit::TestCase
  it 'creates a new Sinatra::Base subclass on new' do
    app = Sinatra.new { get('/') { 'Hello World' } }
    assert_same Sinatra::Base, app.superclass
  end
  
  it "responds to #template_cache" do
    assert_kind_of Tilt::Cache, Sinatra::Base.new!.template_cache
  end
end
