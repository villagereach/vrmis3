class OlmisAreasGenerator < Rails::Generator::Base
  def manifest
    hierarchy = Olmis.area_hierarchy

    record { |m|

      parent_class = nil

      0.upto(hierarchy.length-1) do |i|
        class_name = hierarchy[i]
        file_name = class_name.underscore

        m.class_collisions class_name

        m.template 'administrative_area_model.rb',  File.join('app', 'models', "#{file_name}.rb"), 
          :assigns => { 
            :hierarchy => hierarchy,
            :child => hierarchy[i + 1],
            :parent_class => parent_class,
            :default => definition["default_#{file_name}"],
            :table_name => class_name.tableize,
            :class_name => class_name,
          }

        parent_class = class_name
      end
    }
  end
end
