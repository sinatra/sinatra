# frozen_string_literal: true

# this example does *not* work properly with WEBrick
#
# run *one* of these:
#
#   puma stream.ru                      # gem install puma
#   falcon serve -b http://localhost:9292 -c stream.ru   # gem install falcon

require 'sinatra/base'

class Stream < Sinatra::Base
  get '/' do
    content_type :txt

    stream do |out|
      out << "It's gonna be legen -\n"
      sleep 0.5
      out << " (wait for it) \n"
      sleep 1
      out << "- dary!\n"
    end
  end
end

run Stream
