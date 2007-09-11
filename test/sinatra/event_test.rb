require File.dirname(__FILE__) + '/../helper'

describe "Event" do
  
  it "should return 500 if exception thrown" do
    Sinatra::Environment.set_loggers stub_everything

    event = Sinatra::Event.new(:get, nil) do
      raise 'whaaaa!'
    end
    
    result = event.attend(stub_everything(:params => {}))
    
    result.status.should.equal 500
  end
  
  it "custom error if present" do
    Sinatra::Environment.set_loggers stub_everything
    
    event = Sinatra::Event.new(:get, 404) do
      body 'custom 404'
    end

    Sinatra::EventManager.expects(:not_found).never
    Sinatra::EventManager.determine_event(:get, '/sdf')
  end
  
end
