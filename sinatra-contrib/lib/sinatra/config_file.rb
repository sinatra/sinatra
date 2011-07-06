require 'sinatra/base'
require 'yaml'

module Sinatra

  # = Sinatra::ConfigFile
  #
  # <tt>Sinatra::ConfigFile</tt> is an extension that allows you to load the
  # application's configuration from YAML files.  It automatically detects if
  # the files contains specific environment settings and it will use the
  # corresponding to the current one.
  #
  # Within the application you can access those options through +settings+.  If
  # you try to get the value for a setting that hasn't been defined in the
  # config file for the current environment, you will get whatever it was set
  # to in the application.
  #
  # == Usage
  #
  # Once you have written your configurations to a YAML file you can tell the
  # extension to load them.  See below for more information about how these
  # files are interpreted.
  #
  # For the examples, lets assume the following config.yml file:
  #
  #     greeting: Welcome to my file configurable application
  #
  # === Classic Application
  #
  #     require "sinatra"
  #     require "sinatra/config_file"
  #
  #     config_file 'path/to/config.yml'
  #
  #     get '/' do
  #       @greeting = settings.greeting
  #       haml :index
  #     end
  #
  #     # The rest of your classic application code goes here...
  #
  # === Modular Application
  #
  #     require "sinatra/base"
  #     require "sinatra/config_file"
  #
  #     class MyApp < Sinatra::Base
  #       register Sinatra::ConfigFile
  #
  #       config_file 'path/to/config.yml'
  #
  #       get '/' do
  #         @greeting = settings.greeting
  #         haml :index
  #       end
  #
  #       # The rest of your modular application code goes here...
  #     end
  #
  # === Config File Format
  #
  # In its most simple form this file is just a key-value list:
  #
  #     foo: bar
  #     something: 42
  #     nested:
  #       a: 1
  #       b: 2
  #
  # But it also can provide specific environment configuration.  There are two
  # ways to do that: at the file level and at the setting level.  They are
  # illustrated, repsectively, as follows:
  #
  #     development:
  #       foo: development
  #       bar: bar
  #     test:
  #       foo: test
  #       bar: bar
  #     production:
  #       foo: production
  #       bar: bar
  #
  # and
  #
  #     foo:
  #       development: development
  #       test: test
  #       production: production
  #     bar: bar
  #
  # In either case, <tt>settings.foo</tt> will return the environment name, and
  # <tt>settings.bar</tt> will return <tt>"bar"</tt>.
  #
  # Be aware that if you have a different environment, besides development,
  # test and production, you will also need to adjust the +environments+
  # setting.  For instance, when you also have a staging environment:
  #
  #     set :environments, %w{development test production staging}
  #
  module ConfigFile

    # When the extension is registered sets the +environments+ setting to the
    # traditional environments: development, test and production.
    def self.registered(base)
      base.set :environments, %w[test production development]
    end

    # Loads the configuration from the YAML files whose +paths+ are passed as
    # arguments, filtering the settings for the current environment.  Note that
    # these +paths+ can actually be globs.
    def config_file(*paths)
      Dir.chdir(root || '.') do
        paths.each do |pattern|
          Dir.glob(pattern) do |file|
            $stderr.puts "loading config file '#{file}'" if logging?
            yaml = config_for_env(YAML.load_file(file)) || {}
            yaml.each_pair do |key, value|
              for_env = config_for_env(value)
              set key, for_env unless value and for_env.nil? and respond_to? key
            end
          end
        end
      end
    end

    private

    # Given a +hash+ with some application configuration it returns the
    # settings applicable to the current environment.  Note that this can only
    # be done when all the keys of +hash+ are environment names included in the
    # +environments+ setting (which is an Array of Strings).  Also, the
    # returned config is a indifferently accessible Hash, which means that you
    # can get its values using Strings or Symbols as keys.
    def config_for_env(hash)
      if hash.respond_to? :keys and hash.keys.all? { |k| environments.include? k.to_s }
        hash = hash[environment.to_s] || hash[environment.to_sym]
      end

      if hash.respond_to? :to_hash
        indifferent_hash = Hash.new {|hash,key| hash[key.to_s] if Symbol === key }
        indifferent_hash.merge hash.to_hash
      else
        hash
      end
    end
  end

  register ConfigFile
  Delegator.delegate :config_file
end
