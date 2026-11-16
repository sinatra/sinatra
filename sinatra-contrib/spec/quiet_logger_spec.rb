require 'spec_helper'
require 'sinatra/quiet_logger'
require 'logger'

RSpec.describe Sinatra::QuietLogger do

  it 'logs just paths not excluded' do
    log = StringIO.new
    logger = Logger.new(log)
    mock_app do
      use Rack::CommonLogger, logger
      set :quiet_logger_prefixes, %w(quiet asset)
      register Sinatra::QuietLogger
      get('/log') { 'in log' }
      get('/quiet') { 'not in log' }
    end

    get('/log')
    get('/quiet')

    str = log.string
    expect(str).to include('GET /log')
    expect(str).to_not include('GET /quiet')
  end

  it 'logs paths that only start with an excluded prefix before they are normalized' do
    log = StringIO.new
    logger = Logger.new(log)
    mock_app do
      use Rack::CommonLogger, logger
      set :quiet_logger_prefixes, %w(quiet asset)
      register Sinatra::QuietLogger
      get('/log') { 'in log' }
    end

    get('/quiet/../log')
    expect(last_response.body).to eq('in log')
    get('/quiet/%2e%2e/log')
    expect(last_response.body).to eq('in log')

    str = log.string
    expect(str).to include('GET /quiet/../log')
    expect(str).to include('GET /quiet/%2e%2e/log')
  end

  it 'matches the path as it was sent when it is not normalized for the app' do
    log = StringIO.new
    logger = Logger.new(log)
    mock_app do
      use Rack::CommonLogger, logger
      set :quiet_logger_prefixes, %w(quiet asset)
      register Sinatra::QuietLogger
      set :protection, except: :path_traversal
      get('/log') { 'in log' }
    end

    expect(get('/quiet/../log').status).to eq(404)
    expect(get('/log/../quiet').status).to eq(404)

    str = log.string
    expect(str).not_to include('GET /quiet/../log')
    expect(str).to include('GET /log/../quiet')
  end

  it 'warns about not setting quiet_logger_prefixes' do
    expect {
      mock_app do
        register Sinatra::QuietLogger
      end
    }.to output("You need to specify the paths you wish to exclude from logging via `set :quiet_logger_prefixes, %w(images css fonts)`\n").to_stderr
  end

end
