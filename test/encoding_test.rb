# encoding: UTF-8
require File.dirname(__FILE__) + '/helper'

class BaseTest < Test::Unit::TestCase
  setup do
    @base = Sinatra.new(Sinatra::Base)
    @base.set :views, File.dirname(__FILE__) + "/views"
  end

  it 'allows unicode strings in ascii templates per default (1.9)' do
    next unless defined? Encoding
    @base.new.haml(File.read(@base.views + "/ascii.haml").encode("ASCII"), {}, :value => "åkej")
  end

  it 'allows ascii strings in unicode templates per default (1.9)' do
    next unless defined? Encoding
    @base.new.haml(:utf8, {}, :value => "Some Lyrics".encode("ASCII"))
  end
end