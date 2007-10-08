require File.dirname(__FILE__) + '/../helper'

describe "Event" do
  
  before(:each) do
    Sinatra::EventManager.reset!
  end
  
  it "should return 500 if exception thrown" do
    Sinatra::Environment.prepare_loggers stub_everything

    event = Sinatra::Event.new(:get, '/') do
      raise 'whaaaa!'
    end
    
    result = event.attend(stub_everything(:params => {}, :path_info => '/'))
    
    result.status.should.equal 500
  end
  
  it "custom error if present" do
    Sinatra::Environment.prepare_loggers stub_everything
    
    event = Sinatra::Event.new(:get, '404') do
      body 'custom 404'
    end

    Sinatra::EventManager.expects(:not_found).never
    Sinatra::EventManager.determine_event(:get, '/sdf')
  end
  
  it "should show default 404 if custom not present" do
    Sinatra::EventManager.expects(:not_found)
    Sinatra::EventManager.determine_event(:get, '/asdfsasd')
  end

  it "should not execute event if halted" do
    Sinatra::Event.before_filters << lambda { throw :halt, 'whoa!' }
    event = Sinatra::Event.new(:get, '/') do
      foo
    end
    event.expects(:foo).never
    get_it('/').should.equal 'whoa!'
  end
    
end
