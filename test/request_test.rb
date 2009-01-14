require File.dirname(__FILE__) + '/helper'

describe 'Sinatra::Request' do
  it 'responds to #user_agent' do
    request = Sinatra::Request.new({'HTTP_USER_AGENT' => 'Test'})
    assert request.respond_to?(:user_agent)
    assert_equal 'Test', request.user_agent
  end
end
