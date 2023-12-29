require "bundler/setup"
# This needs to come first so that sinatra require goes through zeitwerk loader
require "zeitwerk"
require "sinatra"

get "/" do
  "OK"
end
