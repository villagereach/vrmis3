namespace :olmis do
  namespace :assets do
    desc "Copy OLMIS assets to the project's public directory"
    task :init => :environment do
      puts "Copying OLMIS assets ..."
      directory = File.dirname(__FILE__) + "/../"
      Dir[directory + "public/**/*"].reject{|f| File.directory?(f) && !File.symlink?(f)}.each do |file|
        destdir = Rails.root + File.dirname(file.sub(directory, ''))
        mkdir_p destdir
        if (File.symlink?(file))
          cd destdir do
            ln_sf File.readlink(file), File.basename(file)
          end
        else
          cp file, destdir
        end
      end
    end
  end
end
