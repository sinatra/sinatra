#!/bin/sh

echo "Running sinatra tests..."
bundle install --jobs=3 --retry=3
bundle exec rake

echo "Running sinatra-contrib tests..."
cd sinatra-contrib
bundle install --jobs=3 --retry=3
bundle exec rake
