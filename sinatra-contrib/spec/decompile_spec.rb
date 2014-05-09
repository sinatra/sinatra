require 'spec_helper'

RSpec::Matchers.define :decompile do |path|
  match do |app|
    @compiled, @keys    = app.send :compile, path
    @decompiled         = app.decompile(@compiled, @keys)
    @decompiled.should == path
  end

  failure_message_for_should do |app|
    values = [app, @compiled, @keys, path, @decompiled].map(&:inspect)
    "expected %s to decompile %s with %s to %s, but was %s" % values
  end
end

describe Sinatra::Decompile do
  subject { Sinatra::Application }
  it { should decompile("") }
  it { should decompile("/") }
  it { should decompile("/?") }
  it { should decompile("/foo") }
  it { should decompile("/:name") }
  it { should decompile("/:name?") }
  it { should decompile("/:foo/:bar") }
  it { should decompile("/page/:id/edit") }
  it { should decompile("/hello/*") }
  it { should decompile("/*/foo/*") }
  it { should decompile("*") }
  it { should decompile(":name.:format") }
  it { should decompile("a b") }
  it { should decompile("a+b") }
  it { should decompile(/./) }
  it { should decompile(/f(oo)/) }
  it { should decompile(/ba+r/) }

  it 'just returns strings' do
    subject.decompile('/foo').should == '/foo'
  end

  it 'just decompile simple regexps without keys' do
    subject.decompile(%r{/foo}).should == '/foo'
  end
end
