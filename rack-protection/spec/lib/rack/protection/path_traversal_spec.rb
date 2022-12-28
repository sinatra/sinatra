# frozen_string_literal: true

RSpec.describe Rack::Protection::PathTraversal do
  it_behaves_like 'any rack application'

  context 'escaping' do
    before do
      mock_app { |e| [200, { 'content-type' => 'text/plain' }, [e['PATH_INFO']]] }
    end

    %w[/foo/bar /foo/bar/ / /.f /a.x].each do |path|
      it("does not touch #{path.inspect}") { expect(get(path).body).to eq(path) }
    end

    { # yes, this is ugly, feel free to change that
      '/..' => '/', '/a/../b' => '/b', '/a/../b/' => '/b/', '/a/.' => '/a/',
      '/%2e.' => '/', '/a/%2E%2e/b' => '/b', '/a%2f%2E%2e%2Fb/' => '/b/',
      '//' => '/', '/%2fetc%2Fpasswd' => '/etc/passwd'
    }.each do |a, b|
      it("replaces #{a.inspect} with #{b.inspect}") { expect(get(a).body).to eq(b) }
    end

    it 'should be able to deal with PATH_INFO = nil (fcgi?)' do
      app = Rack::Protection::PathTraversal.new(proc { 42 })
      expect(app.call({})).to eq(42)
    end
  end

  context "PATH_INFO's encoding" do
    before do
      @app = Rack::Protection::PathTraversal.new(proc { |e| [200, { 'content-type' => 'text/plain' }, [e['PATH_INFO'].encoding.to_s]] })
    end

    it 'should remain unchanged as ASCII-8BIT' do
      body = @app.call({ 'PATH_INFO' => '/'.encode('ASCII-8BIT') })[2][0]
      expect(body).to eq('ASCII-8BIT')
    end
  end
end
