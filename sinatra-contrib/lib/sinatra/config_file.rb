require 'sinatra/base'
require 'yaml'

module Sinatra
  ##
  # = Sinatra::ConfigFile
  #
  # Extension to load configruation from YAML files.
  # Automatically detects if files contain env specific configuration.
  module ConfigFile
    def self.registered(base)
      base.set :environments, %w[test production development]
    end

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
end
