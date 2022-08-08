require 'spec_helper'

RSpec.describe Sinatra::ContentFor do
  subject do
    Sinatra.new do
      helpers Sinatra::ContentFor
      set :views, File.expand_path("content_for", __dir__)
    end.new!
  end

  Tilt.prefer Tilt::ERBTemplate
  require 'hamlit'
  Tilt.register Tilt::HamlTemplate, :haml

  extend Forwardable
  def_delegators :subject, :content_for, :clear_content_for, :yield_content
  def render(engine, template)
    subject.send(:render, engine, template, :layout => false).gsub(/\s/, '')
  end

  describe "without templates" do
    it 'renders blocks declared with the same key you use when rendering' do
      content_for(:foo) { "foo" }
      expect(yield_content(:foo)).to eq("foo")
    end

    it 'renders blocks more than once' do
      content_for(:foo) { "foo" }
      3.times { expect(yield_content(:foo)).to eq("foo") }
    end

    it 'does not render a block with a different key' do
      content_for(:bar) { "bar" }
      expect(yield_content(:foo)).to be_empty
    end

    it 'renders default content if no block matches the key and a default block is specified' do
      expect(yield_content(:foo) {}).to be_nil
      expect(yield_content(:foo) { "foo" }).to eq("foo")
    end

    it 'renders multiple blocks with the same key' do
      content_for(:foo) { "foo" }
      content_for(:foo) { "bar" }
      content_for(:bar) { "WON'T RENDER ME" }
      content_for(:foo) { "baz" }
      expect(yield_content(:foo)).to eq("foobarbaz")
    end

    it 'renders multiple blocks more than once' do
      content_for(:foo) { "foo" }
      content_for(:foo) { "bar" }
      content_for(:bar) { "WON'T RENDER ME" }
      content_for(:foo) { "baz" }
      3.times { expect(yield_content(:foo)).to eq("foobarbaz") }
    end

    it 'passes values to the blocks' do
      content_for(:foo) { |a| a.upcase }
      expect(yield_content(:foo, 'a')).to eq("A")
      expect(yield_content(:foo, 'b')).to eq("B")
    end

    it 'clears named blocks with the specified key' do
      content_for(:foo) { "foo" }
      expect(yield_content(:foo)).to eq("foo")
      clear_content_for(:foo)
      expect(yield_content(:foo)).to be_empty
    end

    it 'takes an immediate value instead of a block' do
      content_for(:foo, "foo")
      expect(yield_content(:foo)).to eq("foo")
    end

    context 'when flush option was disabled' do
      it 'append content' do
        content_for(:foo, "foo")
        content_for(:foo, "bar")
        expect(yield_content(:foo)).to eq("foobar")
      end
    end

    context 'when flush option was enabled' do
      it 'flush first content' do
        content_for(:foo, "foo")
        content_for(:foo, "bar", flush: true)
        expect(yield_content(:foo)).to eq("bar")
      end
    end
  end

  # TODO: liquid markaby builder nokogiri
  engines = %w[erb erubi haml hamlit slim]

  engines.each do |inner|
    describe inner.capitalize do
      before :all do
        begin
          require inner
        rescue LoadError => e
          skip "Skipping: " << e.message
        end
      end

      describe "with yield_content in Ruby" do
        it 'renders blocks declared with the same key you use when rendering' do
          render inner, :same_key
          expect(yield_content(:foo).strip).to eq("foo")
        end

        it 'renders blocks more than once' do
          render inner, :same_key
          3.times { expect(yield_content(:foo).strip).to eq("foo") }
        end

        it 'does not render a block with a different key' do
          render inner, :different_key
          expect(yield_content(:foo)).to be_empty
        end

        it 'renders default content if no block matches the key and a default block is specified' do
          render inner, :different_key
          expect(yield_content(:foo) { "foo" }).to eq("foo")
        end

        it 'renders multiple blocks with the same key' do
          render inner, :multiple_blocks
          expect(yield_content(:foo).gsub(/\s/, '')).to eq("foobarbaz")
        end

        it 'renders multiple blocks more than once' do
          render inner, :multiple_blocks
          3.times { expect(yield_content(:foo).gsub(/\s/, '')).to eq("foobarbaz") }
        end

        it 'passes values to the blocks' do
          render inner, :takes_values
          expect(yield_content(:foo, 1, 2).gsub(/\s/, '')).to eq("<i>1</i>2")
        end
      end

      describe "with content_for in Ruby" do
        it 'renders blocks declared with the same key you use when rendering' do
          content_for(:foo) { "foo" }
          expect(render(inner, :layout)).to eq("foo")
        end

        it 'renders blocks more than once' do
          content_for(:foo) { "foo" }
          expect(render(inner, :multiple_yields)).to eq("foofoofoo")
        end

        it 'does not render a block with a different key' do
          content_for(:bar) { "foo" }
          expect(render(inner, :layout)).to be_empty
        end

        it 'renders multiple blocks with the same key' do
          content_for(:foo) { "foo" }
          content_for(:foo) { "bar" }
          content_for(:bar) { "WON'T RENDER ME" }
          content_for(:foo) { "baz" }
          expect(render(inner, :layout)).to eq("foobarbaz")
        end

        it 'renders multiple blocks more than once' do
          content_for(:foo) { "foo" }
          content_for(:foo) { "bar" }
          content_for(:bar) { "WON'T RENDER ME" }
          content_for(:foo) { "baz" }
          expect(render(inner, :multiple_yields)).to eq("foobarbazfoobarbazfoobarbaz")
        end

        it 'passes values to the blocks' do
          content_for(:foo) { |a,b| "<i>#{a}</i>#{b}" }
          expect(render(inner, :passes_values)).to eq("<i>1</i>2")
        end

        it 'clears named blocks with the specified key' do
          content_for(:foo) { "foo" }
          expect(render(inner, :layout)).to eq("foo")
          clear_content_for(:foo)
          expect(render(inner, :layout)).to be_empty
        end
      end

      describe "with content_for? in Ruby" do
        it 'renders block if key is set' do
          content_for(:foo) { "foot" }
          expect(render(inner, :footer)).to eq("foot")
        end

        it 'does not render a block if different key' do
          content_for(:different_key) { "foot" }
          expect(render(inner, :footer)).to be_empty
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
              skip "Skipping: " << e.message
            end
          end

          before do
            mock_app do
              helpers Sinatra::ContentFor
              set inner, :layout_engine => outer
              set :views, File.expand_path("content_for", __dir__)
              get('/:view') { render(inner, params[:view].to_sym) }
              get('/:layout/:view') do
                render inner, params[:view].to_sym, :layout => params[:layout].to_sym
              end
            end
          end

          describe 'with a default content block' do
            describe 'when content_for key exists' do
              it 'ignores default content and renders content' do
                expect(get('/yield_block/same_key')).to be_ok
                expect(body).to eq("foo")
              end
            end

            describe 'when content_for key is missing' do
              it 'renders default content block' do
                expect(get('/yield_block/different_key')).to be_ok
                expect(body).to eq("baz")
              end
            end
          end

          it 'renders content set as parameter' do
            expect(get('/parameter_value')).to be_ok
            expect(body).to eq("foo")
          end

          it 'renders blocks declared with the same key you use when rendering' do
            expect(get('/same_key')).to be_ok
            expect(body).to eq("foo")
          end

          it 'renders blocks more than once' do
            expect(get('/multiple_yields/same_key')).to be_ok
            expect(body).to eq("foofoofoo")
          end

          it 'does not render a block with a different key' do
            expect(get('/different_key')).to be_ok
            expect(body).to be_empty
          end

          it 'renders multiple blocks with the same key' do
            expect(get('/multiple_blocks')).to be_ok
            expect(body).to eq("foobarbaz")
          end

          it 'renders multiple blocks more than once' do
            expect(get('/multiple_yields/multiple_blocks')).to be_ok
            expect(body).to eq("foobarbazfoobarbazfoobarbaz")
          end

          it 'passes values to the blocks' do
            expect(get('/passes_values/takes_values')).to be_ok
            expect(body).to eq("<i>1</i>2")
          end
        end
      end
    end
  end
end
