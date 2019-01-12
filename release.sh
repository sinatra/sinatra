#!/bin/bash

set -evu

owner=sinatra
repository=sinatra

function halt() {
  echo 1>&2 $*
  exit 0
}

function say() {
  echo 1>&2 $*
}

# To decrypt a private key for use in github.
say "Configures settings for connecting to github remotely.."
# TODO(namusyaka): we need update following line after adding sinatra-bot as a collaborator and executing `travis encrypt-file sinatra-bot`
openssl aes-256-cbc -K $encrypted_5b48ddf2a81f_key -iv $encrypted_5b48ddf2a81f_iv -in sinatra-bot.enc -out ~/.ssh/id_rsa -d
chmod 600 ~/.ssh/id_rsa
echo -e "Host github.com\n\tStrictHostKeyChecking no\n\nIdentityFile ~/.ssh/id_rsa\n" >> ~/.ssh/config

# Configure release commit author.
git config --global user.name "Sinatra Bot"
git config --global user.email "namusyaka+sinatra@gmail.com"
say "done."

say "Makes sure the rubygems credentials exists in correct place.."
mkdir -p ~/.gem && touch ~/.gem/credentials
say "done."

say "Clones a tartget repository.."
git clone git@github.com:$owner/$repository.git -b master
say "done."

cd $repository
bundle install
say "Generates new entry in CHANGELOG.md and Bumps version to new.."
bundle exec rake release:travis
say "done."

if git diff --exit-code; then
  halt "changes seem not to be detected, finished."
fi

say "Releases new versions.."
bundle exec rake release:all
say "done."
