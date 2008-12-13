require 'test/spec'
require 'sinatra/base'
require 'sinatra/test'

describe 'Sinatra::Request' do
  it 'responds to #user_agent' do
    request = Sinatra::Request.new({'HTTP_USER_AGENT' => 'Test'})
    request.should.respond_to :user_agent
    request.user_agent.should.equal 'Test'
  end
end
