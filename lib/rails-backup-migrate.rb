# encoding: UTF-8
#
# @file lib/rails-backup-migrate.rb
#
# @author Matt Connolly
# @copyright 2011 Matt Connolly
#
# This file defines the core of the backup functionality as singleton methods in a Module which
# is used by the rake task.
#
# When required by a Rakefile, this file also loads the rake tasks in lib/tasks/rails-backup-migrate.rake
#

require "#{File.dirname(__FILE__)}/rails-backup-migrate/version"
require 'tmpdir'
require 'fileutils'


module RailsBackupMigrate
  @archive_file = nil
  @files_to_archive = []
  
  VERBOSE =
      if ENV['verbose'] || ENV['VERBOSE']
        true
      else
        false
      end

  # singleton methods for Module `RailsBackupMigrate`
  class << self
    attr_accessor :backup_file
    
    # list the tables we should backup, excluding ones we can ignore
    def interesting_tables
      ActiveRecord::Base.connection.tables.sort.reject do |tbl|
        %w(schema_migrations sessions public_exceptions).include?(tbl)
      end
    end
    
    # add a path to be archived. Expected path to be relative to Rails.root. This is where the archive
    # will be created so that uploaded files (the 'files' dir) can be reference in place without needing to be copied.
    def add_to_archive path
      # check it's relative to Rails.root
      raise "File '#{path}' does not exist" unless File.exist? path
      
      expanded_path = File.expand_path(path)
      if expanded_path.start_with?(rails_root.to_s)
        # remove rails_root from absolute path
        relative = expanded_path.sub(rails_root + File::SEPARATOR,'')
        # add to list
        puts "Adding relative path: '#{relative}'" if VERBOSE
        @files_to_archive << relative
      else
        raise "Cannot add a file that is not under Rails root directory. (#{expanded_path} not under #{rails_root})"
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
      puts "cleaning up." if VERBOSE
      FileUtils.rmtree temp_dir
      @temp_dir = nil
      @files_to_delete_on_cleanup ||= []
      @files_to_delete_on_cleanup.each do |f|
        if File::directory? f
          FileUtils.rm_r f
        else
          FileUtils.rm f
        end
      end
      @files_to_delete_on_cleanup = []
    end
    
    # create the archive .tgz file in the requested location
    def create_archive backup_file
      puts "creating archive..." if VERBOSE
      absolute = File::expand_path backup_file
      Dir::chdir rails_root
      `tar -czf #{absolute} #{files_to_archive.join ' '}`
    end
    
    
    # save the required database tables to .yml files in a folder 'yml' and add them to the backup
    def save_db_to_yml
      FileUtils.chdir rails_root
      FileUtils.mkdir_p 'db/backup'
      FileUtils.chdir 'db/backup'
      
      @files_to_delete_on_cleanup ||= []

      @mysql = ActiveRecord::Base.connection.class.to_s =~ /mysql/i

      interesting_tables.each do |tbl|
        puts "Writing #{tbl}..." if VERBOSE
        File.open("#{tbl}.yml", 'w+') do |f|
          records = ActiveRecord::Base.connection.select_all("SELECT * FROM #{tbl}")
          if @mysql
            # we need to convert Mysql::Time objects into standard ruby time objects because they do not serialise
            # into YAML on their own at all, let alone in a way that would be compatible with other databases
            records.map! do |record|
              record.inject({}) do |memo, (k,v)|
                memo[k] = case v
                            when Mysql::Time
                              datetime_from_mysql_time v
                            else
                              v
                          end
                memo
              end
            end
          end
          f << YAML.dump(records)
        end
        @files_to_delete_on_cleanup << File::expand_path("#{tbl}.yml")
      end
      
      # simply add the whole yml folder to the archive
      FileUtils.chdir rails_root
      add_to_archive 'db/backup'
    end
    
      
    def restore_db_from_yml
      FileUtils.chdir temp_dir + '/db/backup'
      
      interesting_tables.each do |tbl|

        ActiveRecord::Base.transaction do 
        
          puts "Loading #{tbl}..." if VERBOSE
          YAML.load_file("#{tbl}.yml").each do |fixture|
            ActiveRecord::Base.connection.execute "INSERT INTO #{tbl} (#{fixture.keys.join(",")}) VALUES (#{fixture.values.collect { |value| ActiveRecord::Base.connection.quote(value) }.join(",")})", 'Fixture Insert'
          end        
        end
      end
    end
    
    def rails_root
      # in ruby 1.9.3, `Rails.root` is a Pathname object, that plays mess with string comparisons
      # so we'll ensure we have a string
      Rails.root.to_s
    end

    private

    def datetime_from_mysql_time(mysql_time)
        year = mysql_time.year
        month = [1,mysql_time.month].max
        day = [1,mysql_time.day].max
        DateTime.new year, month, day, mysql_time.hour, mysql_time.minute, mysql_time.second
    end

  end
end

if defined?(Rake)
  rake_files = Dir["#{File.dirname(__FILE__)}/tasks/*.rake"]
  rake_files.each { |file| load file }
end


