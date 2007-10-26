require File.dirname(__FILE__) + '/../helper'

context "Filter" do

  before(:each) do
    @befores = Sinatra::Event.before_filters
    Sinatra::Event.before_filters = []
    @afters = Sinatra::Event.after_filters
    Sinatra::Event.after_filters = []
  end
  
  after(:each) do
    Sinatra::Event.before_filters = @befores
    Sinatra::Event.after_filters = @afters
  end
  
  specify "befores can be in front" do
    before_attend :bar
    before_attend :foo, :infront => true
    
    Sinatra::Event.before_filters.should.equal [:foo, :bar]
  end

  specify "afters can be in front" do
    after_attend :bar
    after_attend :foo, :infront => true
    
    Sinatra::Event.after_filters.should.equal [:foo, :bar]
  end
  
end