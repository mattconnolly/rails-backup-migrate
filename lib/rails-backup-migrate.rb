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

  if ENV['verbose'] || ENV['VERBOSE']
    VERBOSE = true
  else
    VERBOSE = false
  end

  # singleton methods for Module `RailsBackupMigrate`
  class << self
    attr_accessor :backup_file

    # list the tables we should backup, excluding ones we can ignore
    def interesting_tables
      tables = ActiveRecord::Base.connection.tables.sort.reject do |tbl|
        ['schema_migrations', 'sessions', 'public_exceptions'].include?(tbl)
      end
    end

    # add a path to be archived. Expected path to be relative to Rails.root. This is where the archive
    # will be created so that uploaded files (the 'files' dir) can be reference in place without needing to be copied.
    def add_to_archive path
      # check it's relative to Rails.root
      raise "File '#{path}' does not exist" unless File::exist? path

      puts "adding path: #{path.inspect}" if VERBOSE

      if File::expand_path(path).start_with? Rails.root
        # remove Rails.root from absolute path
        relative = File::expand_path(path).sub(Rails.root,'')
        # remove leading slash
        relative.gsub! /^#{File::SEPARATOR}/,''
      else
        relative = path
      end

      puts "relative: #{relative.inspect}" if VERBOSE
      # add to list
      @files_to_archive << relative
      puts "added" if VERBOSE
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
        unless File::directory? f
          FileUtils.rm f
        else
          FileUtils.rm_r f
        end
      end
      @files_to_delete_on_cleanup = []
    end

    # create the archive .tgz file in the requested location
    def create_archive backup_file
      puts "creating archive..." if VERBOSE

      absolute = File::expand_path backup_file

      puts "backup_file: #{backup_file.inspect}" if VERBOSE
      puts "absolute: #{absolute.inspect}" if VERBOSE
      puts "files_to_archive = #{files_to_archive.inspect}" if VERBOSE

      Dir::chdir Rails.root
      cmd = "tar -czf #{absolute} #{files_to_archive.join ' '}"
      puts "cmd: #{cmd.inspect}" if VERBOSE

      system cmd
    end

    # save the required database tables to .yml files in a folder 'yml' and add them to the backup
    def save_db_to_yml
      FileUtils.chdir Rails.root
      FileUtils.mkdir_p 'db/backup'
      FileUtils.chdir 'db/backup'

      @files_to_delete_on_cleanup ||= []

      interesting_tables.each do |tbl|
        puts "Writing #{tbl}..." if VERBOSE
        File.open("#{tbl}.yml", 'w+') { |f| f << YAML.dump(ActiveRecord::Base.connection.select_all("SELECT * FROM #{tbl}")) }
        @files_to_delete_on_cleanup << File::expand_path("#{tbl}.yml")
        puts "@files_to_delete_on_cleanup: #{@files_to_delete_on_cleanup.inspect}" if VERBOSE
      end

      # simply add the whole yml folder to the archive
      FileUtils.chdir Rails.root
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
  end
end

if defined?(Rake)
  rake_files = Dir["#{File.dirname(__FILE__)}/tasks/*.rake"]
  rake_files.each { |file| load file }
end
