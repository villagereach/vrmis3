class OlmisTalliesGenerator < Rails::Generator::Base
  def manifest
    definition = eval(File.read(Rails.root.join('config','olmis.rb')))

    record { |m|

      m.directory File.join('app','models')

      definition['tallies'].each do |tally, tally_def|
        puts "creating #{tally}"
        create_tally_model(m, tally, tally_def)
      end
                            
    }
    
  end

  def create_tally_model(m, class_name, tally_def)
    table_name = class_name.tableize
    file_name = table_name.singularize 
    migration_filename = 'create_' + table_name

    defn = {
      'migration_filename'     => migration_filename,
      'table_name'             => table_name,
      'drop_old_table'         => false,
      'class_name'             => class_name,
      'tally_fields'           => [],
      'date_fields'            => [],
      'descriptive_categories' => [],
      'dimensions'             => [],
      'exclude_combinations'   => [],
      'form_tables'            => [],
    }.merge(tally_def)

    if (g = Dir.glob(File.join('db','migrate',"*#{migration_filename}*.rb"))).present?
      last = g.sort.last

      index = 0
      idx = last.gsub(/.*_(\d+)\.rb$/, '\1')
      index = idx.to_i if idx != last

      if index > 0
        defn['migration_filename'] = File.split(last).last.split('_',2).last.gsub(/.rb$/,'')
        defn['drop_old_table']     = true
      else
        new_migration_filename = defn['migration_filename']
      end
      
      if identical?(load_template_file("tally_migration.rb", defn), last)
        logger.identical(last)
      else
        defn['migration_filename'] = new_migration_filename = "recreate_" + table_name + "_%03d" % (index + 1)
        defn['drop_old_table']     = true
        
        m.migration_template("tally_migration.rb", "db/migrate", :migration_file_name => new_migration_filename, :assigns => defn)
        #https://rails.lighthouseapp.com/projects/8994/tickets/487-migration-timestamp-clash-problems-with-generators          
        m.sleep 1
      end
    else
      m.migration_template("tally_migration.rb", "db/migrate", :migration_file_name => migration_filename, :assigns => defn)
      m.sleep 1
    end
      
    m.template "tally_model.rb",  File.join('app', 'models', "#{file_name}.rb"), :assigns => defn
  end
  
  def identical?(string, file)
    File.exists?(file) && !File.directory?(file) && File.read(file) == string
  end
  
  def load_template_file(template, assigns = {})
    b = binding
    assigns.each { |k,v| eval "#{k} = assigns['#{k}']", b }
    ERB.new(File.read(File.join(File.dirname(__FILE__),"templates",template)), nil, '-').result(b)
  end
end
