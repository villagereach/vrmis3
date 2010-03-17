namespace :olmis do
  namespace :db do
    desc "foo"
    task :bootstrap => :environment do
      Olmis.bootstrap      
    end
  end
end
