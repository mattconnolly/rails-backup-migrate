# encoding: UTF-8
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
      puts "adding db/schema.rb to archive list." if RailsBackupMigrate::VERBOSE
      Dir::chdir Rails.root
      RailsBackupMigrate.add_to_archive 'db/schema.rb'
    end
    
    # private task: save the database tables to yml files
    task :_save_db_to_yml, [:backup_file] => [:environment] do |t, args|
      RailsBackupMigrate.save_db_to_yml
    end
    
    # private task: finalise the archive, used as a dependency after :_save_db_to_yml and/or :_save_db_schema
    task :_finish_archive, [:backup_file] => []  do |t, args|
      args.with_defaults(:backup_file => "site-backup.tgz")
      RailsBackupMigrate.create_archive args.backup_file
      RailsBackupMigrate.clean_up
    end
    
    # private task: add the `files` directory to the archive
    task :_add_files_directory_to_archive, [:backup_file] do |t, args|
      puts "adding 'files' dir to archive list." if RailsBackupMigrate::VERBOSE
      if (File.exist?("files") && File.directory?("files"))
        RailsBackupMigrate.add_to_archive "files" 
      else
        puts "Warning, cannot archive 'files' directory, it does not exist." if RailsBackupMigrate::VERBOSE
      end
    end
    
    desc "Dump schema to a backup file. Default backup = 'site-backup.tgz'."
    task :schema, [:backup_file] => [:_save_db_schema, :_finish_archive] do |t, args|
    end
    
    desc "Dump schema and entire db in YML files to a backup file. Default backup = 'site-backup.tgz'"
    task :db, [:backup_file] => [:_save_db_schema, :_save_db_to_yml, :_finish_archive] do |t, args|
    end
    
    desc "Archive all files in the `files` directory into a backup file. Default backup = 'site-backup.tgz'"
    task :files, [:backup_file] => [:_add_files_directory_to_archive, :_finish_archive] do |t,args|
    end
    
  end
  
  desc "Backup everything: schema, database to yml, and all files in 'files' directory. Default backup file is 'site-backup.tgz'"
  task :backup, [:backup_file] => [
    'site:backup:_save_db_schema', 
    'site:backup:_save_db_to_yml', 
    'site:backup:_add_files_directory_to_archive',
    'site:backup:_finish_archive'] do
  end
  
  
  namespace :restore do
    
    # private task: set the backup file to the parameter passed to rake, or the default. Saves the absolute path for later.
    task :_set_backup_file, [:backup_file] => [:environment] do |t, args|
      args.with_defaults(:backup_file => "site-backup.tgz")
      
      abort "File does not exist" unless
        File.exist? args.backup_file
      
      RailsBackupMigrate.backup_file = File::expand_path args.backup_file
    end
    
    # private task: restore db/schema.rb, expected to be a dependency before 'db:schema:load'
    task :_restore_db_schema, [:backup_file] => [:_set_backup_file] do |t, args|[]
      puts "restoring db/schema.rb from archive." if RailsBackupMigrate::VERBOSE
      Dir::chdir Rails.root
      # extract the schema.rb file in place
      options = RailsBackupMigrate::VERBOSE ? '-xvzf' : '-xzf'
      `tar #{options} #{RailsBackupMigrate.backup_file} db/schema.rb`
    end
    
    # private task: restore the database tables from yml files
    task :_restore_db_from_yml, [:backup_file] => [:_restore_db_schema, 'db:schema:load'] do |t, args|
      Dir::chdir RailsBackupMigrate.temp_dir
      # extract the yml files
      options = RailsBackupMigrate::VERBOSE ? '-xvzf' : '-xzf'
      `tar #{options} #{RailsBackupMigrate.backup_file} 'db/backup'`
      RailsBackupMigrate.restore_db_from_yml
    end
    
    # private task: restore 'files' directory. Should we delete the contents of it?? not for now...
    task :_restore_files_directory, [:backup_file] => [:_set_backup_file] do |t, args|
      Dir::chdir Rails.root
      # extract the 'files' directory in place
      
      # check if there is 'files/' in the archive file (perhaps this app doesn't have downloads)
      # fixing issue #2 on github.
      `tar -tzf #{RailsBackupMigrate.backup_file} | grep '^files/'`
      if $? == 0
        options = RailsBackupMigrate::VERBOSE ? '-xvzf' : '-xzf'
        `tar #{options} #{RailsBackupMigrate.backup_file} files`
      else
        puts "Warning: cannot extract 'files', not in archive" if RailsBackupMigrate::VERBOSE
      end
    end
    
    desc "Erase and reload db schema from backup file. Default backup file is 'site-backup.tgz'. Runs `rake db:schema:load`."
    task :schema, [:backup_file] => [:_restore_db_schema, 'db:schema:load'] do |t, args|
      RailsBackupMigrate.clean_up
    end
    
    desc "Erase and reload entire db schema and data from backup file. Runs `rake db:schema:load`. Runs `rake db:schema:load`"
    task :db, [:backup_file] => [:_restore_db_from_yml] do |t, args|
      RailsBackupMigrate.clean_up
    end
    
    desc "Restore all files in the 'files' directory. Default backup file is 'site-backup.tgz'."
    task :files, [:backup_file] => [:_restore_files_directory] do |t,args|
      RailsBackupMigrate.clean_up
    end
    
  end
  
  desc "Erase and reload db schema and data from backup files, and restore all files in the 'files' directory. Default backup file is 'site-backup.tgz'. Runs `rake db:schema:load`."
  task :restore, [:backup_file] => [
    'site:restore:_restore_db_schema',
    'db:schema:load',
    'site:restore:_restore_db_from_yml',
    'site:restore:_restore_files_directory'] do
  end 
  
end