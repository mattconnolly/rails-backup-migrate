# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "rails-backup-migrate/version"

Gem::Specification.new do |s|
  s.name        = "rails-backup-migrate"
  s.version     = RailsBackupMigrate::VERSION
  s.authors     = ["Matt Connolly"]
  s.email       = ["matt@soundevolution.com.au"]
  s.homepage    = "http://github.com/mattconnolly/rails-backup-migrate"
  s.summary     = %q{Backup and restore a rails application including database data and files}
  s.description = %q{Creates a directory db/backup in the rails app and creates / loads YML files from there. 
    After a backup, the db/backups directory is archived into a .tgz file and then deleted.
    When restoring, the db/backup directory is extracted from the .tgz file.
    All of the files in the 'files' directory are also backed up / restored.
    
    The default archive file is "site-backup.tgz" but any other one can be passed as an argument to both db:backup:write
    and db:backup:read, for example:
    
    app1$ rake db:backup:write
    app1$ cd ../app2
    app2$ rake db:backup:read[../app1/site-backup.tgz]
    
    The environment variable 'verbose' or 'VERBOSE' if defined will result in some verbose output.
    
    To add the rake tasks to your Rails app, simply install the gem, and then add the following line to your 'Rakefile':
    
        require 'rails-backup-migrate'
    
    }

  s.rubyforge_project = "rails-backup-migrate"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  
  s.add_dependency "activerecord", ">= 2.3"
end
