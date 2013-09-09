require File.expand_path('../spec_helper.rb', __FILE__)

describe Rack::Protection::Base do
  describe "#random_string" do
    it "outputs a string of 32 characters" do
      described_class.new(lambda {}).random_string.length.should == 32
    end
  end
end
