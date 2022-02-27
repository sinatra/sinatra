# -*- coding: utf-8 -*-
require 'slim'
require 'spec_helper'

RSpec.describe Sinatra::Capture do
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
    lang = engine
    if engine == :erubi
      lang = :erb
    end
    if engine == :hamlit
      lang = :haml
    end
    require "#{engine}"

    it "captures content" do
      expect(render(engine, "simple_#{lang}")).to eq("Say Hello World!")
    end

    it "allows nested captures" do
      expect(render(engine, "nested_#{lang}")).to eq("Say Hello World!")
    end
  end

  describe('haml')   { it_behaves_like "a template language", :haml   }
  describe('hamlit') { it_behaves_like "a template language", :hamlit }
  describe('slim')   { it_behaves_like "a template language", :slim   }
  describe('erubi')  { it_behaves_like "a template language", :erubi  }

  describe 'erb' do
    it_behaves_like "a template language", :erb

    it "handles utf-8 encoding" do
      expect(render(:erb, "utf_8")).to eq("UTF-8 –")
    end

    it "handles ISO-8859-1 encoding" do
      expect(render(:erb, "iso_8859_1")).to eq("ISO-8859-1 -")
    end
  end

  describe 'without templates' do
    it 'captures empty blocks' do
      expect(capture {}).to be_nil
    end
  end
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

@@ utf_8
<% a = capture do %>–<% end %>
UTF-8 <%= a %>

@@ iso_8859_1
<% a = capture do %>-<% end %>
ISO-8859-1 <%= a.force_encoding("iso-8859-1") %>
