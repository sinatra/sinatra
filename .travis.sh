#!/bin/bash
set -ev

echo "Running sinatra tests..."
bundle exec rake

echo "Running sinatra-contrib tests..."
export BUILDIR=$TRAVIS_BUILD_DIR/sinatra-contrib
export BUNDLE_GEMFILE=$BUILDIR/Gemfile
cd $BUILDIR
bundle install --jobs=3 --retry=3
bundle exec rake

echo "Running rack-protection tests..."
export BUILDIR=$TRAVIS_BUILD_DIR/rack-protection
export BUNDLE_GEMFILE=$BUILDIR/Gemfile
cd $BUILDIR
bundle install --jobs=3 --retry=3
bundle exec rake
