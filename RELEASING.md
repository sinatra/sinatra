# Releasing Sinatra 🥂

This document explains releasing process for all Sinatra gems.

Since everything is bundled in same repo (except `Mustermann`), we now
have one rake task to cut a release.

(Please refer to [Mustermann](https://github.com/sinatra/mustermann) if that also needs a release.)

### Releasing
For relesing new version of [`sinatra`, `sinatra-contrib`, `rack-protection`], this is the procedure:

1. Update `VERSION` file with target version
2. Run `bundle exec rake release:all`
3. ???
4. Profit!!!

Thats it!

This rake task can be broken down as:

* Pick up latest version string from `VERSION` file
* Run all tests to ensure gems are not broken
* Update `version.rb` file in all gems with latest `VERSION`
* Create a new commit with new `VERSION` and `version.rb` files
* Tag the commit with same version
* Push the commit and tags to github
* Package all the gems, ie create all `.gem` files
* Ensure that all the gems can be installed locally
* If no issues, push all gems to upstream.

In addition to above rake task, there are other rake tasks which can help
with development.

### Packaging
These rake tasks will generate `.gem` and `.tar.gz` files. For each gem,
there is one dedicated rake task.

```sh
# Build sinatra-contrib package
$ bundle exec rake package:sinatra-contrib

# Build rack-protection package
$ bundle exec rake package:rack-protection

# Build sinatra package
$ bundle exec rake package:sinatra

# Build all packages
$ bundle exec rake package:all
```

### Packaging and installing locally
These rake tasks will package all the gems, and install them locally

```sh
# Build and install sinatra-contrib gem locally
$ bundle exec rake install:sinatra-contrib

# Build and install rack-protection gem locally
$ bundle exec rake install:rack-protection

# Build and install sinatra gem locally
$ bundle exec rake install:sinatra

# Build and install all gems locally
$ bundle exec rake install:all
```
