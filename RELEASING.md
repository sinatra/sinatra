# Releasing Sinatra 🥂

This document explains releasing process for all Sinatra gems.

Since everything is bundled in same repo (except `Mustermann`), we
have some rake tasks and a GitHub Actions workflow to cut a release.

(Please refer to [Mustermann](https://github.com/sinatra/mustermann) if that also needs a release.)

### Releasing

For releasing new version of [`sinatra`, `sinatra-contrib`, `rack-protection`], this is the procedure:

1. Update `CHANGELOG.md`
1. Update `VERSION` file with target version
1. Run `rake release:commit_version`
1. Create pull request with all that ([example](https://github.com/sinatra/sinatra/pull/1893))
1. Merge the pull request when CI is green
1. Ensure you have latest changes locally
1. Run `rake release:tag_version`
1. Push tag to upstream
1. Run `rake release:watch` and watch GitHub Actions push to RubyGems.org

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
