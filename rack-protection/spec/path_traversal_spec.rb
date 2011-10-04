require File.expand_path('../spec_helper.rb', __FILE__)

describe Rack::Protection::PathTraversal do
  it_behaves_like "any rack application"

  context 'escaping' do
    before do
      mock_app { |e| [200, {'Content-Type' => 'text/plain'}, [e['PATH_INFO']]] }
    end

    %w[/foo/bar /foo/bar/ / /.f /a.x].each do |path|
      it("does not touch #{path.inspect}") { get(path).body.should == path }
    end

    { # yes, this is ugly, feel free to change that
      '/..' => '/', '/a/../b' => '/b', '/a/../b/' => '/b/', '/a/.' => '/a/',
      '/%2e.' => '/', '/a/%2e%2e/b' => '/b', '/a%2f%2e%2e%2fb/' => '/b/',
      '//' => '/', '/%2fetc%2fpasswd' => '/etc/passwd'
    }.each do |a, b|
      it("replaces #{a.inspect} with #{b.inspect}") { get(a).body.should == b }
    end

    it 'should be able to deal with PATH_INFO = nil (fcgi?)' do
      app = Rack::Protection::PathTraversal.new(proc { 42 })
      app.call({}).should be == 42
    end
  end
end
