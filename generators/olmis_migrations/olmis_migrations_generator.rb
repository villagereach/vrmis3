class OlmisMigrationsGenerator < Rails::Generator::Base
  def manifest
    record { |m|
      Dir.glob(File.join(File.dirname(__FILE__),'templates','*.rb')).sort.each do |g|
        filename = File.split(g).last
        migration_filename = filename.gsub(/^\d+_(.*)\.rb$/, 'olmis_\1')

        if m.migration_exists?(migration_filename)
          logger.exists migration_filename 
        else
          m.migration_template filename, "db/migrate", :migration_file_name => migration_filename 

          #https://rails.lighthouseapp.com/projects/8994/tickets/487-migration-timestamp-clash-problems-with-generators          
          m.sleep 1
        end
      end
    }
  end
end
