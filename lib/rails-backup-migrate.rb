require "rails-backup-migrate/version"
require 'tmpdir'
require 'fileutils'

module RailsBackupMigrate
  @archive_file = nil
  @files_to_archive = []
  
  puts "Now self is '#{self.inspect}', of type '#{self.class}'"
  
  # singleton methods for Module `RailsBackupMigrate`
  class << self
    attr_accessor :backup_file
    
    # list the tables we should backup, excluding ones we can ignore
    def interesting_tables
      ActiveRecord::Base.connection.tables.sort.reject do |tbl|
        ['schema_migrations', 'sessions', 'public_exceptions'].include?(tbl)
      end
    end
    
    # add a path to be archived. Expected path to be relative to RAILS_ROOT. This is where the archive
    # will be created so that uploaded files (the 'files' dir) can be reference in place without needing to be copied.
    def add_to_archive path
      # check it's relative to RAILS_ROOT
      raise "File '#{path}' does not exist" unless File::exist? path
      
      if File::expand_path(path).start_with? RAILS_ROOT
        # remove RAILS_ROOT from absolute path
        relative = File::expand_path(path).sub(RAILS_ROOT,'')
        # remove leading slash
        relative.gsub! /^#{File::SEPARATOR}/,''
        # add to list
        @files_to_archive << relative
      end
    end
  
    def files_to_archive
      @files_to_archive
    end
    
    # get a temp directory to be used for the backup
    # the value is cached so it can be reused throughout the process
    def temp_dir
      unless defined? @temp_dir
        @temp_dir = Dir.mktmpdir
      end
      @temp_dir
    end
    
    
    # delete any working files
    def clean_up
      puts "cleaning up."
      FileUtils.rmtree temp_dir
      @temp_dir = nil
      @files_to_delete_on_cleanup ||= []
      @files_to_delete_on_cleanup.each do |f|
        unless File::directory? f
          FileUtils.rm f
        else
          FileUtils.rm_r f
        end
      end
      @files_to_delete_on_cleanup = []
    end
    
    # expand an archive, expects an absolute path to the .tgz file
    def extract_archive backup_file
      puts "extracting archive..."
      puts "listing files..."
      files = ``
      # add the yml files to a delete
      Dir.chdir temp_dir
      `tar -xzf #{backup_file}`
    end
    
    # create the archive .tgz file in the requested location
    def create_archive backup_file
      puts "creating archive..."
      absolute = File::expand_path backup_file
      Dir::chdir RAILS_ROOT
      `tar -czf #{absolute} #{files_to_archive.join ' '}`
    end
    
    
    # save the required database tables to .yml files in a folder 'yml' and add them to the backup
    def save_db_to_yml
      FileUtils.chdir RAILS_ROOT
      FileUtils.mkdir_p 'db/backup'
      FileUtils.chdir 'db/backup'
      
      @files_to_delete_on_cleanup ||= []
      
      interesting_tables.each do |tbl|
        puts "Writing #{tbl}..."
        File.open("#{tbl}.yml", 'w+') { |f| YAML.dump ActiveRecord::Base.connection.select_all("SELECT * FROM #{tbl}"), f }
        @files_to_delete_on_cleanup << File::expand_path("#{tbl}.yml")
      end
      
      # simply add the whole yml folder to the archive
      FileUtils.chdir RAILS_ROOT
      add_to_archive 'db/backup'
    end
    
      
    def restore_db_from_yml
      FileUtils.chdir temp_dir + '/db/backup'
      
      interesting_tables.each do |tbl|

        ActiveRecord::Base.transaction do 
        
          puts "Loading #{tbl}..."
          YAML.load_file("#{tbl}.yml").each do |fixture|
            ActiveRecord::Base.connection.execute "INSERT INTO #{tbl} (#{fixture.keys.join(",")}) VALUES (#{fixture.values.collect { |value| ActiveRecord::Base.connection.quote(value) }.join(",")})", 'Fixture Insert'
          end        
        end
      end
    end
  end
end

if defined?(Rake)
  rake_files = Dir["#{File.dirname(__FILE__)}/tasks/*.rake"]
  rake_files.each { |file| load file }
end


