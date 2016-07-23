#!/bin/bash
set -ev

echo "Running sinatra tests..."
bundle exec rake

echo "Running sinatra-contrib tests..."
cd $TRAVIS_BUILD_DIR/sinatra-contrib
bundle install --jobs=3 --retry=3
bundle exec rake
