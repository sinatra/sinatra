# this example does *not* work properly with WEBrick
#
# run *one* of these:
#
#   rackup -s mongrel stream.ru         # gem install mongrel
#   unicorn stream.ru                   # gem install unicorn
#   puma stream.ru                      # gem install puma
#   rainbows -c rainbows.conf stream.ru # gem install rainbows eventmachine

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
