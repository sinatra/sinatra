require 'backports'
require 'slim'
require_relative 'spec_helper'

describe Sinatra::Capture do
  subject do
    Sinatra.new do
      enable :inline_templates
      helpers Sinatra::Capture
    end.new!
  end
  Tilt.prefer Tilt::ERBTemplate

  extend Forwardable
  def_delegators :subject, :capture, :capture_later

  def render(engine, template)
    subject.send(:render, engine, template.to_sym).strip.gsub(/\s+/, ' ')
  end

  shared_examples_for "a template language" do |engine|
    lang = engine == :erubis ? :erb : engine

    it "captures content" do
      begin
        render(engine, "simple_#{lang}").should == "Say Hello World!"
      rescue => e
        t = Tilt[:slim].new { subject.settings.templates[:"nested_#{lang}"][0] }
        puts t.send(:precompiled, [])
        raise e
      end
    end

    it "allows nested captures" do
      begin
        render(engine, "nested_#{lang}").should == "Say Hello World!"
      rescue => e
        t = Tilt[:slim].new { subject.settings.templates[:"nested_#{lang}"][0] }
        puts t.send(:precompiled, [])
        raise e
      end
    end
  end

  describe('haml')   { it_behaves_like "a template language", :haml   }
  describe('slim')   { it_behaves_like "a template language", :slim   }
  describe('erb')    { it_behaves_like "a template language", :erb    }
  describe('erubis') { it_behaves_like "a template language", :erubis }
end

__END__

@@ simple_erb
Say
<% a = capture do %>World<% end %>
Hello <%= a %>!

@@ nested_erb
Say
<% a = capture do %>
  <% b = capture do %>World<% end %>
  <%= b %>!
<% end %>
Hello <%= a.strip %>

@@ simple_slim
| Say 
- a = capture do
  | World
| Hello #{a.strip}!

@@ nested_slim
| Say 
- a = capture do
  - b = capture do
    | World
  | #{b.strip}!
| Hello #{a.strip}

@@ simple_haml
Say
- a = capture do
  World
Hello #{a.strip}!

@@ nested_haml
Say
- a = capture do
  - b = capture do
    World
  #{b.strip}!
Hello #{a.strip}
