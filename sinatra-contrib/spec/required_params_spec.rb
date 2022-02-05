require_relative 'spec_helper'

RSpec.describe Sinatra::RequiredParams do
  context "#required_params" do
    context "simple keys" do
      before do
        mock_app do
          helpers Sinatra::RequiredParams
          get('/') { required_params(:p1, :p2) }
        end
      end
      it 'return 400 if required params do not exist' do
        get('/')
        expect(last_response.status).to eq(400)
      end
      it 'return 400 if required params do not exist partially' do
        get('/', :p1 => 1)
        expect(last_response.status).to eq(400)
      end
      it 'return 200 if required params exist' do
        get('/', :p1 => 1, :p2 => 2)
        expect(last_response.status).to eq(200)
      end
      it 'return 200 if required params exist with array' do
        get('/', :p1 => 1, :p2 => [31, 32, 33])
        expect(last_response.status).to eq(200)
      end
    end
    context "hash keys" do
      before do
        mock_app do
          helpers Sinatra::RequiredParams
          get('/') { required_params(:p1, :p2 => :p21) }
        end
      end
      it 'return 400 if required params do not exist' do
        get('/')
        expect(last_response.status).to eq(400)
      end
      it 'return 200 if required params exist' do
        get('/', :p1 => 1, :p2 => {:p21 => 21})
        expect(last_response.status).to eq(200)
      end
      it 'return 400 if p2 is not a hash' do
        get('/', :p1 => 1, :p2 => 2)
        expect(last_response.status).to eq(400)
      end
    end
    context "complex keys" do
      before do
        mock_app do
          helpers Sinatra::RequiredParams
          get('/') { required_params(:p1 => [:p11, {:p12 => :p121, :p122 => [:p123, {:p124 => :p1241}]}]) }
        end
      end
      it 'return 400 if required params do not exist' do
        get('/')
        expect(last_response.status).to eq(400)
      end
      it 'return 200 if required params exist' do
        get('/', :p1 => {:p11 => 11, :p12 => {:p121 => 121}, :p122 => {:p123 => 123, :p124 => {:p1241 => 1241}}})
        expect(last_response.status).to eq(200)
      end
    end
  end

  context "#_required_params" do
    it "is invisible" do
      expect { _required_params }.to raise_error(NameError)
    end
  end
end
