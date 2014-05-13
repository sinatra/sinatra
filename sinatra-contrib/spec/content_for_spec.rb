require 'spec_helper'

describe Sinatra::ContentFor do
  subject do
    Sinatra.new do
      helpers Sinatra::ContentFor
      set :views, File.expand_path("../content_for", __FILE__)
    end.new!
  end

  Tilt.prefer Tilt::ERBTemplate

  extend Forwardable
  def_delegators :subject, :content_for, :yield_content
  def render(engine, template)
    subject.send(:render, engine, template, :layout => false).gsub(/\s/, '')
  end

  describe "without templates" do
    it 'renders blocks declared with the same key you use when rendering' do
      content_for(:foo) { "foo" }
      yield_content(:foo).should == "foo"
    end

    it 'renders blocks more than once' do
      content_for(:foo) { "foo" }
      3.times { yield_content(:foo).should == "foo" }
    end

    it 'does not render a block with a different key' do
      content_for(:bar) { "bar" }
      yield_content(:foo).should be_empty
    end

    it 'renders multiple blocks with the same key' do
      content_for(:foo) { "foo" }
      content_for(:foo) { "bar" }
      content_for(:bar) { "WON'T RENDER ME" }
      content_for(:foo) { "baz" }
      yield_content(:foo).should == "foobarbaz"
    end

    it 'renders multiple blocks more than once' do
      content_for(:foo) { "foo" }
      content_for(:foo) { "bar" }
      content_for(:bar) { "WON'T RENDER ME" }
      content_for(:foo) { "baz" }
      3.times { yield_content(:foo).should == "foobarbaz" }
    end

    it 'passes values to the blocks' do
      content_for(:foo) { |a| a.upcase }
      yield_content(:foo, 'a').should == "A"
      yield_content(:foo, 'b').should == "B"
    end
  end

  # TODO: liquid radius markaby builder nokogiri
  engines = %w[erb erubis haml slim]

  engines.each do |inner|
    describe inner.capitalize do
      before :all do
        begin
          require inner
        rescue LoadError => e
          pending "Skipping: " << e.message
        end
      end

      describe "with yield_content in Ruby" do
        it 'renders blocks declared with the same key you use when rendering' do
          render inner, :same_key
          yield_content(:foo).strip.should == "foo"
        end

        it 'renders blocks more than once' do
          render inner, :same_key
          3.times { yield_content(:foo).strip.should == "foo" }
        end

        it 'does not render a block with a different key' do
          render inner, :different_key
          yield_content(:foo).should be_empty
        end

        it 'renders multiple blocks with the same key' do
          render inner, :multiple_blocks
          yield_content(:foo).gsub(/\s/, '').should == "foobarbaz"
        end

        it 'renders multiple blocks more than once' do
          render inner, :multiple_blocks
          3.times { yield_content(:foo).gsub(/\s/, '').should == "foobarbaz" }
        end

        it 'passes values to the blocks' do
          render inner, :takes_values
          yield_content(:foo, 1, 2).gsub(/\s/, '').should == "<i>1</i>2"
        end
      end

      describe "with content_for in Ruby" do
        it 'renders blocks declared with the same key you use when rendering' do
          content_for(:foo) { "foo" }
          render(inner, :layout).should == "foo"
        end

        it 'renders blocks more than once' do
          content_for(:foo) { "foo" }
          render(inner, :multiple_yields).should == "foofoofoo"
        end

        it 'does not render a block with a different key' do
          content_for(:bar) { "foo" }
          render(inner, :layout).should be_empty
        end

        it 'renders multiple blocks with the same key' do
          content_for(:foo) { "foo" }
          content_for(:foo) { "bar" }
          content_for(:bar) { "WON'T RENDER ME" }
          content_for(:foo) { "baz" }
          render(inner, :layout).should == "foobarbaz"
        end

        it 'renders multiple blocks more than once' do
          content_for(:foo) { "foo" }
          content_for(:foo) { "bar" }
          content_for(:bar) { "WON'T RENDER ME" }
          content_for(:foo) { "baz" }
          render(inner, :multiple_yields).should == "foobarbazfoobarbazfoobarbaz"
        end

        it 'passes values to the blocks' do
          content_for(:foo) { |a,b| "<i>#{a}</i>#{b}" }
          render(inner, :passes_values).should == "<i>1</i>2"
        end
      end

      describe "with content_for? in Ruby" do
        it 'renders block if key is set' do
          content_for(:foo) { "foot" }
          render(inner, :footer).should == "foot"
        end

        it 'does not render a block if different key' do
          content_for(:different_key) { "foot" }
          render(inner, :footer).should be_empty
        end
      end

      engines.each do |outer|
        describe "with yield_content in #{outer.capitalize}" do
          def body
            last_response.body.gsub(/\s/, '')
          end

          before :all do
            begin
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
              get('/:view') { render(inner, params[:view].to_sym) }
              get('/:layout/:view') do
                render inner, params[:view].to_sym, :layout => params[:layout].to_sym
              end
            end
          end

          it 'renders blocks declared with the same key you use when rendering' do
            get('/same_key').should be_ok
            body.should == "foo"
          end

          it 'renders blocks more than once' do
            get('/multiple_yields/same_key').should be_ok
            body.should == "foofoofoo"
          end

          it 'does not render a block with a different key' do
            get('/different_key').should be_ok
            body.should be_empty
          end

          it 'renders multiple blocks with the same key' do
            get('/multiple_blocks').should be_ok
            body.should == "foobarbaz"
          end

          it 'renders multiple blocks more than once' do
            get('/multiple_yields/multiple_blocks').should be_ok
            body.should == "foobarbazfoobarbazfoobarbaz"
          end

          it 'passes values to the blocks' do
            get('/passes_values/takes_values').should be_ok
            body.should == "<i>1</i>2"
          end
        end
      end
    end
  end
end
