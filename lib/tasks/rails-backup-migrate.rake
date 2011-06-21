namespace :db do
  namespace :backup do
    
    def interesting_tables
      ActiveRecord::Base.connection.tables.sort.reject do |tbl|
        ['schema_migrations', 'sessions', 'public_exceptions'].include?(tbl)
      end
    end
  
  
    # private: extract the db-backup.tgz file
    task :extract_schema_and_yml_data, [:backup_file]=> [:environment] do |t, args|
      args.with_defaults(:backup_file => "db-backup.tgz")
      backup_file = File.expand_path args.backup_file
      
      abort "File does not exist" unless
        File.exist? backup_file
        
      puts "Extracting data from: #{args.backup_file} ..."
      Dir.chdir RAILS_ROOT
      `tar -xzf '#{backup_file}' db/schema.rb db/backup`
    end
    
    
    desc "Dump entire db to YML files in db/backup. Runs `db:schema:dump` so db/schema.rb is up to date."
    task :write, [:backup_file] => [:environment, 'db:schema:dump'] do |t, args|
      args.with_defaults(:backup_file => "db-backup.tgz")
      backup_file = File.expand_path args.backup_file

      dir = RAILS_ROOT + '/db/backup'
      FileUtils.mkdir_p(dir)
      FileUtils.chdir(dir)
    
      interesting_tables.each do |tbl|

        puts "Writing #{tbl}..."
        File.open("#{tbl}.yml", 'w+') { |f| YAML.dump ActiveRecord::Base.connection.select_all("SELECT * FROM #{tbl}"), f }
      end
    
      puts "Creating archive..."
      Dir.chdir RAILS_ROOT
      `tar -czf '#{backup_file}' db/schema.rb db/backup`
      
      # remove the 'db/backup' directory and all its files
      FileUtils.rm_r(dir)
    end
  
  
    desc "Erase and reload entire db. Runs `rake db:schema:load`."
    task :read, [:backup_file] => [:environment, :extract_schema_and_yml_data, 'db:schema:load'] do |t, args|
      args.with_defaults(:backup_file => "db-backup.tgz")

      dir = RAILS_ROOT + '/db/backup'
      FileUtils.chdir(dir)
    
      interesting_tables.each do |tbl|

        ActiveRecord::Base.transaction do 
        
          puts "Loading #{tbl}..."
          YAML.load_file("#{tbl}.yml").each do |fixture|
            ActiveRecord::Base.connection.execute "INSERT INTO #{tbl} (#{fixture.keys.join(",")}) VALUES (#{fixture.values.collect { |value| ActiveRecord::Base.connection.quote(value) }.join(",")})", 'Fixture Insert'
          end        
        end
      end
      
      # remove the 'db/backup' directory and all its files
      FileUtils.rm_r(dir)
    end
  
  end
end