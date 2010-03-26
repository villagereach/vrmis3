namespace :olmis do
  namespace :assets do
    desc "Copy OLMIS assets to the project's public directory"
    task :init => :environment do
      puts "Copying OLMIS assets ..."
      directory = File.dirname(__FILE__) + "/../"
      destdir = "#{Rails.root}/public"
      mkdir_p destdir
      sh "rsync -rvu #{directory}/public/* #{destdir}"
    end
  end
end
