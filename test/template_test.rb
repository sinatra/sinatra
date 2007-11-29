require File.dirname(__FILE__) + '/helper'

context "Templates (in general)" do
  
  specify "are read from files if Symbols" do
    
    get '/from_file' do
      @name = 'Alena'
      render :foo, :views_directory => File.dirname(__FILE__) + "/views"
    end
    
    get_it '/from_file'
    
    body.should.equal 'You rock Alena!'
    
  end
  
end
