namespace :olmis do
  namespace :assets do
    desc "Copy OLMIS assets to the project's public directory"
    task :init => :environment do
      puts "Copying OLMIS assets ..."
      directory = File.dirname(__FILE__) + "/../"
      destdir = "#{Rails.root}/public"
      mkdir_p destdir
      sh "rsync -rlvu --exclude 'custom.*' #{directory}/public/* #{destdir}"

      # Copy over 'custom.*' files only if they do not already exist in destdir
      Dir.chdir("#{directory}/public") do
        Dir.glob("**/custom.*").each do |file|
          FileUtils.cp(file, "#{destdir}/#{file}") unless File.exist?("#{destdir}/#{file}")
        end
      end
    end
  end
end
