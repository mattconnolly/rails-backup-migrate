require "db-backup/version"

if defined?(Rake)
  rake_files = Dir["#{File.dirname(__FILE__)}/tasks/*.rake"]
  rake_files.each { |file| load file }
end