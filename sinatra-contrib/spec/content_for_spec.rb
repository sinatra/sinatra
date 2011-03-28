require 'backports'
require_relative 'spec_helper'

describe Sinatra::ContentFor do
  # TODO: erubis slim liquid radius markaby builder nokogiri
  engines = %w[erb haml]
  engines.each do |inner|
    engines.each do |outer|
      describe "#{inner.capitalize} templates with #{outer.capitalize} layouts" do
        def body
          super.gsub(/\s/, '')
        end

        before do
          pending "different layout engines not supported yet" unless inner == outer
        end

        before :all do
          begin
            require inner
            require outer
          rescue LoadError => e
            pending "Skipping: " << e.message
          end
        end

        before do
          mock_app do
            helpers Sinatra::ContentFor
            set inner, :layout_engine => outer
            set :views, File.expand_path("../content_for", __FILE__)
            get('/:view') { send(inner, params[:view].to_sym) }
            get('/:layout/:view') do
              send inner, params[:view].to_sym, :layout => params[:layout].to_sym
            end
          end
        end

        it 'renders blocks declared with the same key you use when rendering' do
          get('/same_key').should be_ok
          body.should == "foo"
        end

        it 'does not render a block with a different key' do
          get('/different_key').should be_ok
          body.should == ""
        end

        it 'renders multiple blocks with the same key'do
          get('/multiple_blocks').should be_ok
          body.should == "foobarbaz"
        end

        it 'passes values to the blocks' do
          get('/passes_values/takes_values').should be_ok
          body.should == "<i>1</i>2"
        end
      end
    end
  end
end
