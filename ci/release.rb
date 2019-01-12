require 'octokit'

module Release
  # Config represents configuration struct for use in application.
  Config = Struct.new(:repository, :github_access_token, :branch, :pull_request_branch, :commit_message) do
    # Returns true if the current build is eligible for release.
    # @return [TrueClass, FalseClass]
    def build_target?
      branch == 'master' && pull_request_branch == '' && pr_no != 0
    end

    # Gets the pull request number from the current commit message.
    # Returns zero if the pull request number cannot be found.
    # @return [Integer]
    def pull_request_number
      Release.pr_no_from(commit_message)
    end
    alias pr_no pull_request_number
  end

  # Changelog represents the change log abstraction, it's used for
  # generating valid section for `path`.
  Changelog = Struct.new(:name, :path, :version, :pull_requests) do
    # Insert a section in `path` before top section.
    def update!
      File.open(path, 'r+') do |f|
        line = f.read
        f.seek(0)
        f.puts(to_s)
        f.write(line)
      end
    end

    # Converts into section which is consist of heading and release notes.
    # @return [String]
    def to_s
      heading = "# v#{version} / #{Time.now.strftime('%Y-%m-%d')}"
      heading + "\n\n" + release_note + "\n\n"
    end

    private

    def release_note
      return "Nothing" if pull_requests.length.zero?
      pull_requests.map { |pull_request|
        entry = "* #{pull_request.title.capitalize}"
        entry += " [##{pull_request.number}](https://github.com/#{name}/pull/#{pull_request.number}) by"
        entry += " [@#{pull_request.user.login}](https://github.com/#{pull_request.user.login})"
      }.join(?\n)
    end
  end

  class API
    attr_reader :client, :repository

    def initialize(name, access_token)
      @client = Octokit::Client.new(access_token: access_token)
      @repository = @client.repo name
    end

    def get_pull_request(pr_no)
      fetch { repository.rels[:issues].get(uri: { number: pr_no }) }
    end

    def get_latest_version
      return unless data = fetch { repository.rels[:tags].get }
      data.first.name
    end

    def get_commits_between(base:, head: 'master')
      return [] unless data = fetch { repository.rels[:compare].get(uri: { base: base, head: head }) }
      data.commits.map(&:commit)
    end

    private

    def fetch
      response = yield
      response.status == 200 ? response.data : nil
    end
  end

  module Helpers
    def pull_request_number_from_commit_message(message)
      matched = message.match(%r{Merge pull request #(\d+) from})
      return 0 unless matched
      matched[1].to_i
    end
    alias pr_no_from pull_request_number_from_commit_message

    # Increments version to next release version
    #
    # @example
    #   increment_version(2.0.1, candidate: false) => 2.0.2
    #   increment_version(2.0.1, candidate: true) => 2.0.2.rc
    #   increment_version(2.0.1.rc, candidate: false) => 2.0.1
    #   increment_version(2.0.1.rc, candidate: true) => 2.0.1.rc1
    #   increment_version(2.0.1.rc1, candidate: false) => 2.0.1
    #   increment_version(2.0.1.rc1, candidate: true) => 2.0.1.rc2
    #   increment_version(2.0.1.rc2, candidate: false) => 2.0.1
    #   increment_version(2.0.1.rc2, candidate: true) => 2.0.1.rc3
    #   increment_version(2.0.1.beta1, candidate: false) => 2.0.1
    #   increment_version(2.0.1.beta1, candidate: true) => 2.0.1.beta2
    #   increment_version(2.0.1.beta2, candidate: false) => 2.0.1
    #   increment_version(2.0.1.beta2, candidate: true) => 2.0.1.beta3
    def increment_version(version, candidate: false)
      major, minor, patch, suffix = version.split(?., 4)
      major = major.slice(1..-1) if version.start_with?(?v)
      matched = (suffix || '').match(%r{(rc|beta)([\d]*)\z})
      # Bump patch version to next unless previous version doesn't have any candidate suffixes.
      patch = patch.to_i.next unless matched
      if candidate
        suffix = matched ? "#{matched[1]}#{matched[2].to_i.next}" : 'rc'
      else
        suffix = nil
      end
      "#{major}.#{minor}.#{patch}#{".#{suffix}" if suffix && !suffix.empty?}"
    end

    def config
      @config ||= Config.new
    end

    def say(message)
      puts message.strip
      exit 0
    end
  end

  extend self
  extend Helpers

  def run!
    # Validate current build whether it is targed for releasing patch version
    say <<-EOS unless config.build_target?
      Auto release doesn't proceed releasing if the trigger commit isn't merge commit. 
    EOS

    # Generate API client
    api = API.new(config.repository, config.github_access_token)

    # Abort if a pull request cannot be found by given pr no.
    say <<-EOS unless pull_request = api.get_pull_request(config.pr_no)
      Cannot detect a pull request ##{config.pr_no}
    EOS

    # Abort if the "release/patch" label cannot be found from the pull request.
    say <<-EOS unless pull_request.labels.any? { |label| label.name == 'release/patch' }
      Cannot detect the "release/patch" label in pull request ##{config.pr_no}
    EOS

    # Release candidate version if the pull request has the 'release/candidate' label.
    candidate = pull_request.labels.any? { |label| label.name == 'release/candidate' }

    # Abort if available tag does not exist.
    say <<-EOS unless latest_version = api.get_latest_version
      Cannot detect any tags
    EOS

    # Get targeted commits between latest version and head.
    commits = api.get_commits_between(base: latest_version)
    # Select pull requests for updating changelog
    pull_requests = commits.each_with_object([]) do |commit, pull_requests|
      # Skip non-merge commit
      next unless commit.committer.name == "GitHub" && commit.committer.email == "noreply@github.com"
      # Skip if the pull request number cannot be found
      pr_no = pr_no_from(commit.message)
      next if pr_no == 0
      # Skip if the pull request cannot be found by given number
      next unless pull_request = api.get_pull_request(pr_no)
      # Skip if the pull request does not contains the "release-note" label
      next unless pull_request.labels.any? { |label| label.name == 'release-note' }
      pull_requests << pull_request
    end

    # Bump version to next version
    next_version = increment_version(latest_version, candidate: candidate)
    changelog = Changelog.new(config.repository, 'CHANGELOG.md', next_version, pull_requests).update!

    # Bump VERSION to next
    File.write('VERSION', next_version)
  end

  def configure
    yield(config)
  end
end

# Configure required values
Release.configure do |cfg|
  cfg.repository          = ENV['TRAVIS_REPO_SLUG']
  cfg.branch              = ENV['TRAVIS_BRANCH']
  cfg.commit_message      = ENV['TRAVIS_COMMIT_MESSAGE']
  cfg.pull_request_branch = ENV['TRAVIS_PULL_REQUEST_BRANCH']
  cfg.github_access_token = ENV['GITHUB_ACCESS_TOKEN']
end

Release.run!
