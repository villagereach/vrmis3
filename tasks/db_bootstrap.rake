namespace :olmis do
  namespace :db do
    desc "Reads the OLMIS config file and populates the database with initial data."
    task :bootstrap => :environment do
      Olmis.bootstrap      
    end
  end
end
