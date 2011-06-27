#
# @file lib/tasks/rails-backup-migrate.rake
#
# @author Matt Connolly
# @copyright 2011 Matt Connolly
#
# this file defines the rake tasks for backing up a rails application (site) including
# optionally, the database and the files, or both.
#

require 'tmpdir'

namespace :site do
  namespace :backup do
    
    # private task: save the db/schema.rb file, calls 'db:schema:dump' as a dependency
    task :_save_db_schema, [:backup_file] => [:environment, 'db:schema:dump'] do |t, args|
      puts "adding db/schema.rb to archive list."
      Dir::chdir RAILS_ROOT
      RailsBackupMigrate.add_to_archive 'db/schema.rb'
    end
    
    # private task: save the database tables to yml files
    task :_save_db_to_yml, [:backup_file] => [:environment] do |t, args|
      puts "_save_db_to_yml"
      RailsBackupMigrate.save_db_to_yml
    end
    
    # private task: finalise the archive, used as a dependency after :_save_db_to_yml and/or :_save_db_schema
    task :_finish_archive, [:backup_file] => []  do |t, args|
      args.with_defaults(:backup_file => "db-backup.tgz")
      RailsBackupMigrate.create_archive args.backup_file
      RailsBackupMigrate.clean_up
    end
    
    desc "Dump schema to a backup file. Default backup = 'db-backup.tgz'."
    task :schema, [:backup_file] => [:_save_db_schema, :_finish_archive] do |t, args|
      puts "nothing really left to do :)"
    end
    
    desc "Dump schema and entire db in YML files to a backup file. Default backup = 'db-backup.tgz'."
    task :db, [:backup_file] => [:_save_db_schema, :_save_db_to_yml, :_finish_archive] do |t, args|
      puts "nothing really left to do :)"
    end
    
  end
  
  
  namespace :restore do
    
    # private task: set the backup file to the parameter passed to rake, or the default. Saves the absolute path for later.
    task :_set_backup_file, [:backup_file] => [:environment] do |t, args|
      puts "setting backup file"
      args.with_defaults(:backup_file => "db-backup.tgz")
      
      abort "File does not exist" unless
        File.exist? args.backup_file
      
      RailsBackupMigrate.backup_file = File::expand_path args.backup_file
    end
    
    # private task: restore db/schema.rb, expected to be a dependency before 'db:schema:load'
    task :_restore_db_schema, [:backup_file] => [:_set_backup_file] do |t, args|[]
      puts "restoring db/schema.rb from archive."
      Dir::chdir RAILS_ROOT
      # extract the schema.rb file in place
      `tar -xzf #{RailsBackupMigrate.backup_file} db/schema.rb`
    end
    
    # private task: restore the database tables from yml files
    task :_restore_db_from_yml, [:backup_file] => [:_restore_db_schema, 'db:schema:load'] do |t, args|
      puts "_restore_db_from_yml"
      Dir::chdir RailsBackupMigrate.temp_dir
      # extract the yml files
      `tar -xzf #{RailsBackupMigrate.backup_file} 'db/backup/*.yml'`
      RailsBackupMigrate.restore_db_from_yml
    end
    
    desc "Erase and reload db schema from backup file. Default backup file is 'db-backup.tgz'. Runs `rake db:schema:load`."
    task :schema, [:backup_file] => [:_restore_db_schema, 'db:schema:load'] do |t, args|
      puts "nothing really left to do :)"
      RailsBackupMigrate.clean_up
    end
    
    desc "Erase and reload entire db. Runs `rake db:schema:load`."
    task :db, [:backup_file] => [:_restore_db_from_yml] do |t, args|
      RailsBackupMigrate.clean_up
    end
  
    desc "Print out some debug info"
    task :debug do |t, args|
      puts self
      p "self.inspect = #{self.inspect}"
      self_class = (class << self ; self end)
      p "class << self = #{self_class}"
      puts "\n\nThese are the files to backup:\n#{RailsBackupMigrate.files_to_archive.join "\n"}"
    end
    
  end
  
  desc "Dump schema and entire db in YML files to a backup file. Default backup = 'db-backup.tgz'."
  task :backup => 'backup:db' do
    puts "default task"
  end
  
  desc "Erase and reload entire db. Runs `rake db:schema:load`."
  task :restore => 'restore:db' do
    puts "default task"
  end 
  
end