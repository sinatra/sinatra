require File.dirname(__FILE__) + '/helper'

# XXX: How does any of this have anything to do with REST?
context "RESTful tests" do

  specify "should take xml" do
    post '/foo.xml' do
      request.body.string
    end

    post_it '/foo.xml', '<myxml></myxml>'
    assert ok?
    assert_equal('<myxml></myxml>', body)
  end

end

