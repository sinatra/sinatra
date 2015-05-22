# -*- coding: utf-8 -*-
require 'slim'
require 'spec_helper'

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
    require "#{engine}"

    it "captures content" do
      render(engine, "simple_#{lang}").should == "Say Hello World!"
    end

    it "allows nested captures" do
      render(engine, "nested_#{lang}").should == "Say Hello World!"
    end
  end

  describe('haml')   { it_behaves_like "a template language", :haml   }
  describe('slim')   { it_behaves_like "a template language", :slim   }
  describe('erubis') { it_behaves_like "a template language", :erubis }

  describe 'erb' do
    it_behaves_like "a template language", :erb

    it "handles utf-8 encoding" do
      render(:erb, "utf_8").should == "UTF-8 –"
    end

    it "handles ISO-8859-1 encoding" do
      render(:erb, "iso_8859_1").should == "ISO-8859-1 -"
    end if RUBY_VERSION >= '1.9'
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
