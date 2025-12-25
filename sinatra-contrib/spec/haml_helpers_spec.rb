require 'haml'
require 'spec_helper'
require 'sinatra/haml_helpers'

RSpec.describe Sinatra::HamlHelpers do
  let(:quote_char) { Haml::VERSION >= "7.0.0" ? "\"" : "'" }

  describe "#surround" do
    it "renders correctly" do
      mock_app do
        helpers Sinatra::HamlHelpers
        get "/" do
          haml_code = <<~HAML
            %p
              != surround "(", ")" do
                %a{ href: "https://example.org/" } surrounded
          HAML
          haml haml_code
        end
      end

      get "/"
      html_code = <<~HTML
        <p>
        (<a href=#{quote_char}https://example.org/#{quote_char}>surrounded</a>)
        </p>
      HTML
      expect(body).to eq(html_code)
    end
  end

  describe "#precede" do
    it "renders correctly" do
      mock_app do
        helpers Sinatra::HamlHelpers
        get "/" do
          haml_code = <<~HAML
            %p
              != precede "* " do
                %a{ href: "https://example.org/" } preceded
          HAML
          haml haml_code
        end
      end

      get "/"
      html_code = <<~HTML
        <p>
        * <a href=#{quote_char}https://example.org/#{quote_char}>preceded</a>
        </p>
      HTML
      expect(body).to eq(html_code)
    end
  end

  describe "#succeed" do
    it "renders correctly" do
      mock_app do
        helpers Sinatra::HamlHelpers
        get "/" do
          haml_code = <<~HAML
            %p
              != succeed "." do
                %a{ href: "https://example.org/" } succeeded
          HAML
          haml haml_code
        end
      end

      get "/"
      html_code = <<~HTML
        <p>
        <a href=#{quote_char}https://example.org/#{quote_char}>succeeded</a>.
        </p>
      HTML
      expect(body).to eq(html_code)
    end
  end
end
