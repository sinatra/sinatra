require 'set'

module Sinatra
  module Loader
    extend self

    def reload!
      silence_warnings do
        EventManager.reset!
        load_files loaded_files
        load $0
      end
    end

    def load_files(*files)
      files = files.flatten
      files = files.first if files.first.is_a? Set

      files.each do |file| 
        file = File.expand_path(file)
        load file
        loaded_files << file
      end
    end
    alias_method :load_file, :load_files

    def loaded_files
      @loaded_files ||= Set.new
    end
  end
end 
