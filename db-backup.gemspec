# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "db-backup/version"

Gem::Specification.new do |s|
  s.name        = "db-backup"
  s.version     = Db::Backup::VERSION
  s.authors     = ["Matt Connolly"]
  s.email       = ["matt@soundevolution.com.au"]
  s.homepage    = ""
  s.summary     = %q{Backup and restore a rails application to YML files}
  s.description = %q{Creates a directory db/backup in the rails app and creates / loads YML files from there.}

  s.rubyforge_project = "db-backup"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
