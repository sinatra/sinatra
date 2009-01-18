require File.dirname(__FILE__) + '/helper'

describe "Sinatra::Test" do
  it "support nested parameters" do
    mock_app {
      get '/' do
        params[:post][:title]
      end

      post '/' do
        params[:post][:content]
      end
    }

    get '/', :post => { :title => 'My Post Title' }
    assert_equal 'My Post Title', body

    post '/', :post => { :content => 'Post Content' }
    assert_equal 'Post Content', body
  end
end
