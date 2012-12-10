require File.expand_path('../spec_helper.rb', __FILE__)

describe Rack::Protection do
  it_behaves_like "any rack application"

  it 'passes on options' do
    mock_app do
      use Rack::Protection, :track => ['HTTP_FOO']
      run proc { |e| [200, {'Content-Type' => 'text/plain'}, ['hi']] }
    end

    session = {:foo => :bar}
    get '/', {}, 'rack.session' => session, 'HTTP_ACCEPT_ENCODING' => 'a'
    get '/', {}, 'rack.session' => session, 'HTTP_ACCEPT_ENCODING' => 'b'
    session[:foo].should be == :bar

    get '/', {}, 'rack.session' => session, 'HTTP_FOO' => 'BAR'
    session.should be_empty
  end

  describe "#html?" do
    context "given an appropriate content-type header" do
      subject { Rack::Protection::Base.new(nil).html? 'content-type' => "text/html" }
      it { should be_true }
    end

    context "given an inappropriate content-type header" do
      subject { Rack::Protection::Base.new(nil).html? 'content-type' => "image/gif" }
      it { should be_false }
    end

    context "given no content-type header" do
      subject { Rack::Protection::Base.new(nil).html?({}) }
      it { should be_false }
    end
  end
end
