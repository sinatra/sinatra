require File.dirname(__FILE__) + '/helper'

context "A Route in general" do
    
  specify "matches a path to a block" do
    e = Sinatra::Route.new('/') do
      'hello'
    end
    
    result = e.match('/')
    result.block.call.should.equal 'hello'
    result.params.should.be.empty
  end
  
  specify "matches with params from path" do
    e = Sinatra::Route.new('/:name') do
      'hello again'
    end

    # spaces should work
    result = e.match('/blake%20mizerany')
    result.should.not.be.nil
    result.block.call.should.equal 'hello again'
    result.params.should.equal :name => 'blake mizerany'
  end
  
  specify "matches multiple vars in path" do
    e = Sinatra::Route.new('/:name/:age') do
      'hello again'
    end

    # spaces should work
    result = e.match('/blake%20mizerany/25')
    result.should.not.be.nil
    result.block.call.should.equal 'hello again'
    result.params.should.equal :name => 'blake mizerany', :age => '25'
  end
    
end
