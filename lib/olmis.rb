require 'yaml/encoding'
class Olmis
  class << self
    def path
      Rails.root.join('config','olmis.rb')
    end

    def configured?
      File.exists?(path)
    end

    def configuration
      if configured?
        @configuration ||= eval(File.read(path))
      else
        raise "Please create an OLMIS configuration file at #{path}"
      end
    end

    def tally_klasses
      tallies = configuration['tallies'] || {}
      tallies.keys.map(&:constantize)
    end
    
    def additional_visit_klasses
      (configuration['additional_visit_tables'] || []).map(&:constantize)
    end
    
    def area_hierarchy
      @area_hierarchy ||= configuration['administrative_area_hierarchy']
    end
  
    def bootstrap
      definition = configuration
      ActiveRecord::Base.transaction do
        @translations = { }
        definition['languages'].each do |lc|
          @translations[lc] = (YAML.load_file(Rails.root.join('config','locales',"#{lc}.yml")) rescue {})
        end
          
        definition['roles'].each do |l, options|
          Role.find_or_initialize_by_code(l).update_attributes!(options)
        end
  
        pt_by_code = {}
        pd_by_code = {}

        unless User.find_by_username('admin')
          User.create!(
            :username => 'admin', :role => Role.find_by_code('admin'),
            :password => 'olmis', :password_confirmation => 'olmis', 
            :language => definition['languages'].first, 
            :timezone => definition['time_zone'])
        end

        definition['product_types'].each_with_index do |p, i|
          attrs = { :active => true, :position => i }
          attrs.merge!(:trackable => p['trackable']) if p.has_key?('trackable')
          pt_by_code[p['code']] = ProductType.find_or_initialize_by_code(p['code'])
          pt_by_code[p['code']].update_attributes!(attrs)
        end

        definition['products'].each_with_index do |p,i|
          pd_by_code[p['code']] = Product.find_or_initialize_by_code(p['code'])
          pd_by_code[p['code']].update_attributes!( :active => true, :product_type_id => pt_by_code[p['type']].id, :position => i)
        end

        definition['packages'].each_with_index do |p,i|
          attrs = { :active => true, :product_id => pd_by_code[p['product']].id, :quantity => p['quantity'], :position => i }
          attrs.merge!(:primary_package => p['primary_package']) if p.has_key?('primary_package')
          Package.find_or_initialize_by_code(p['code']).update_attributes!(attrs)
        end

        definition['equipment'].each_with_index do |e,i|
          EquipmentType.find_or_initialize_by_code(e).update_attributes!( :active => true, :position => i )
        end

        (definition['cold_chain'] + [{'code' => 'unknown', 'capacity' => 0.0}]).each_with_index do |f, i|
          FridgeModel.find_or_initialize_by_code(f['code']).update_attributes!( f.merge({:active => true, :position => i}) )
        end
  
        definition['stock_cards'].each_with_index do |f, i|
          StockCard.find_or_initialize_by_code(f).update_attributes!(:active => true, :position => i)
        end

        invalidate_old(ProductType,   definition['product_types'])
        invalidate_old(Product,       definition['products'])
        invalidate_old(Package,       definition['packages'])
        invalidate_old(EquipmentType, definition['equipment'].map { |e| { 'code' => e } } )
        invalidate_old(FridgeModel,   definition['cold_chain'])
        invalidate_old(StockCard,     definition['stock_cards'].map { |e| { 'code' => e } })

        hierarchy = definition['administrative_area_hierarchy']
        create_hierarchy(nil, hierarchy, definition['administrative_areas'])
  
        create_zones_and_warehouses(definition['warehouses'])
  
        create_health_centers(
          definition['health_centers'], 
          hierarchy, 
          definition['fridge_code_pattern'])
  
        definition['descriptive_categories'].each do |cat, vals|
          dc = DescriptiveCategory.find_or_create_by_code(cat)
          vals.each_with_index do |v, i|
            dv = dc.descriptive_values.find_or_create_by_code(v)
            dv.update_attributes!(:position => i)
          end
        end
  
        definition['targets'].each do |target, target_def|
          create_target(target, target_def)
        end

        @translations.each do |lc, hash|
          fn = Rails.root.join('config','locales',lc+'.yml').to_s
          File.open(fn + '~', 'w') do |f|
            f.write( YAML.unescape(hash.to_yaml() ) )
          end
          File.rename(fn + '~', fn)
        end
      end
    end

    def invalidate_old(model, definition)
      model.find(:all,
        :conditions => ['code not in (?)', definition.map { |d| d['code'] }],
          :order => 'position asc').
        each_with_index do |p, i|
        p.update_attributes!( :active => false, :position => definition.length + i)
      end
    end

    def name_to_code(name, klass=nil, options={})
      code = options[:code] || (options[:area] ? "#{name}-#{options[:area]}" : name).to_url

      if klass
        key = "#{klass}.#{code}"
        @codes_by_key ||= {}
        return @codes_by_key[key] if @codes_by_key.has_key?(key)
        @codes_by_key[key] = code
        @translations.each do |lc, hash|
          hash[lc] ||= {}
          hash[lc][klass] ||= {}
          hash[lc][klass][code] ||= name
        end
      end

      code
    end

    def create_zones_and_warehouses(warehouses)
      warehouses.each do |whn, hash|
        wh_code = name_to_code(whn, 'Warehouse')
        wh = Warehouse.find_or_initialize_by_code(wh_code)
        zones = hash.delete('DeliveryZones')

        unless wh.stock_room
          wh.stock_room = StockRoom.create!
        end
        
        k = hash.keys.first
        aa = k.constantize
        wh.administrative_area = aa.find_by_code(name_to_code(hash[k], k))

        wh.code = wh_code

        wh.save!
        zones.each do |zone_n|
          dz_code = name_to_code(zone_n, 'DeliveryZone')
          DeliveryZone.find_or_initialize_by_code(dz_code).update_attributes!(:warehouse => wh, :code => dz_code)
        end
        unless wh.street_address
          StreetAddress.create!(:addressed => wh)
        end
      end
    end

    def create_health_centers(health_centers, hierarchy, fridge_code_pattern)
      health_centers.each do |name, data|
        dz_code = name_to_code(data['DeliveryZone'], 'DeliveryZone')
        dz = DeliveryZone.find_or_initialize_by_code(dz_code)

        if dz.new_record?
          dz.update_attributes!(:warehouse => Warehouse.first, :code => dz_code)
        end

        area = hierarchy.detect { |h| data.has_key?(h) }

        aa_code = name_to_code(data[area], area)
        a = AdministrativeArea.find_by_code(aa_code)

        begin
          hc_code = name_to_code(name, 'HealthCenter', :area => data[area])
          h = a.health_centers.find_or_initialize_by_code(hc_code)
        rescue
          raise aa_code
        end

        unless h.stock_room
          h.stock_room = StockRoom.create!
        end

        h.update_attributes!(:code => hc_code, :delivery_zone => dz, :administrative_area => a, :catchment_population => data['population'])
        
        unless h.street_address
          StreetAddress.create!(:addressed => h)
        end
      end
    end

    def create_hierarchy(parent, hierarchy, areas)
      return if hierarchy.empty?
      parent_class = parent.class.name if parent
      class_name = hierarchy[0]
      table_name = class_name.tableize

      child = hierarchy[1] # nil if outside array bounds

      default_pair = areas.detect { |k,v| v['default'] } if areas
      default = default_pair ? name_to_code(default_pair.first) : nil

      dz = false

      klass = class_name.constantize

      if areas
        areas.each do |name, subhierarchy|
          code = name_to_code(name, class_name, :code => subhierarchy['code'])
          area = klass.find_or_initialize_by_code(code)
          area.update_attributes!(:parent => parent, :code => code, :population => subhierarchy['population'])

          if subhierarchy['latitude'] && !area.street_address
            StreetAddress.create!(:addressed => area, :latitude => subhierarchy['latitude'], :longitude => subhierarchy['longitude'])
          end

          create_hierarchy(area, hierarchy[1..-1], subhierarchy[child])
        end
      end
    end

    def create_target(name, definition)
      code = name_to_code(name, 'TargetPercentage')
      target = TargetPercentage.find_or_initialize_by_code(code)
      target.attributes = { :percentage => definition['percentage'], :code => code, :stat_tally_klass => definition['tally'] }
      target.save(false)
      
      target.descriptive_values = definition['values'].map { |v| cat, val = v.split(':'); DescriptiveCategory.find_by_code(cat).descriptive_values.find_by_code(val) }
    end
  end  
end

