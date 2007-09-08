require File.dirname(__FILE__) + '/../helper'

describe "Event" do
  
  it "should return 500 if exception thrown" do
    set_logger stub_everything

    event = Sinatra::Event.new(:get, nil) do
      raise 'whaaaa!'
    end
    
    result = event.attend(stub_everything)
    
    result.status.should.equal 500
  end
  
end
