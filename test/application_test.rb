require File.dirname(__FILE__) + '/helper'

context "Simple Events" do

  setup do
    @app = Sinatra::Application.new
  end

  specify "return what's at the end" do
    @app.define_event(:get, '/') do
      'Hello'
    end
        
    result = @app.lookup(
      'REQUEST_METHOD' => 'GET',
      'PATH_INFO' => '/'
    )
    
    result.should.not.be.nil
    result.body.should.equal 'Hello'
  end
  
  specify "takes params in path" do
    @app.define_event(:get, '/:foo') do
      'World'
    end
    
    result = @app.lookup(
      'REQUEST_METHOD' => 'GET',
      'PATH_INFO' => '/bar'
    )
    
    result.should.not.be.nil
    result.body.should.equal 'World'
    result.params.should.equal :foo => 'bar'
  end
          
end
