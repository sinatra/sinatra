require File.expand_path('../spec_helper.rb', __FILE__)

describe Rack::Protection::Base do
  describe "#random_string" do
    it "outputs a string of 32 characters" do
      described_class.new(lambda {}).random_string.length.should == 32
    end
  end

  describe "#referrer" do
    it "Reads referrer from Referrer header" do
      env = {"HTTP_HOST" => "foo.com", "HTTP_REFERER" => "http://bar.com/valid"}
      described_class.new(lambda {}).referrer(env).should == "bar.com"
    end

    it "Reads referrer from Host header when Referrer header is relative" do
      env = {"HTTP_HOST" => "foo.com", "HTTP_REFERER" => "/valid"}
      described_class.new(lambda {}).referrer(env).should == "foo.com"
    end

    it "Reads referrer from Host header when Referrer header is missing" do
      env = {"HTTP_HOST" => "foo.com"}
      described_class.new(lambda {}).referrer(env).should == "foo.com"
    end

    it "Returns nil when Referrer header is missing and allow_empty_referrer is false" do
      env = {"HTTP_HOST" => "foo.com"}
      base = described_class.new(lambda {}, :allow_empty_referrer => false)
      base.referrer(env).should be_nil
    end

    it "Returns nil when Referrer header is invalid" do
      env = {"HTTP_HOST" => "foo.com", "HTTP_REFERER" => "http://bar.com/bad|uri"}
      base = described_class.new(lambda {})
      base.referrer(env).should be_nil
    end
  end
end
