require 'spec_helper'
require 'sinatra/custom_logger'

describe Sinatra::CustomLogger do
  before do
    rack_logger = @rack_logger = double
    mock_app do
      helpers Sinatra::CustomLogger

      before do
        env['rack.logger'] = rack_logger
      end

      get '/' do
        logger.info 'Logged message'
        'Response'
      end
    end
  end

  describe '#logger' do
    it 'falls back to request.logger' do
      expect(@rack_logger).to receive(:info).with('Logged message')
      get '/'
    end

    context 'logger setting is set' do
      before do
        custom_logger = @custom_logger = double
        @app.class_eval do
          configure do
            set :logger, custom_logger
          end
        end
      end

      it 'calls custom logger' do
        expect(@custom_logger).to receive(:info).with('Logged message')
        get '/'
      end
    end
  end
end
