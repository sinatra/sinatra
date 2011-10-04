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
end
