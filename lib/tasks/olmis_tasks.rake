namespace :olmis do
  namespace :assets do
    desc "Copy OLMIS assets to the project's public directory"
    task :init => :environment do
      puts "Copying OLMIS assets..."
      directory = File.dirname(__FILE__) + "/../../"
      Dir[directory + "public/**/*"].reject{|f| File.directory?(f)}.each do |file|
        path = file.sub(directory, '')
        dir = File.dirname(path)
        mkdir_p Rails.root + dir
        cp file, Rails.root + path
      end
    end
  end
end
