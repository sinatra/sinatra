require 'test/spec'
require 'sinatra/base'
require 'sinatra/test'

$reload_count = 0
$reload_app = nil

describe "Reloading" do
  include Sinatra::Test

  before {
    @app = mock_app(Sinatra::Default)
    $reload_app = @app
  }

  after {
    $reload_app = nil
  }

  it 'is enabled by default when in development and the app_file is set' do
    @app.set :app_file, __FILE__
    @app.set :environment, :development
    @app.reload.should.be true
    @app.reload?.should.be true
  end

  it 'is disabled by default when running in non-development environment' do
    @app.set :app_file, __FILE__
    @app.set :environment, :test
    @app.reload.should.not.be true
    @app.reload?.should.be false
  end

  it 'is disabled by default when no app_file is available' do
    @app.set :app_file, nil
    @app.set :environment, :development
    @app.reload.should.not.be true
    @app.reload?.should.be false
  end

  it 'can be turned off explicitly' do
    @app.set :app_file, __FILE__
    @app.set :environment, :development
    @app.reload.should.be true
    @app.set :reload, false
    @app.reload.should.be false
    @app.reload?.should.be false
  end

  it 'reloads the app_file each time a request is made' do
    @app.set :app_file, File.dirname(__FILE__) + '/data/reload_app_file.rb'
    @app.set :reload, true
    @app.get('/') { 'Hello World' }

    get '/'
    status.should.equal 200
    body.should.equal 'Hello from reload file'
    $reload_count.should.equal 1

    get '/'
    status.should.equal 200
    body.should.equal 'Hello from reload file'
    $reload_count.should.equal 2
  end
end
