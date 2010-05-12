# Models that include ActsAsStatTally must conform to a basic structure: 
# * integer 'value' column representing a tally
# * health_center_id foreign key
# * date_period string 
# * created_by/updated_by foreign keys 
# * a set of foreign keys to descriptive_values, partitioned by descriptive_categories.  
#   Each foreign key can take any descriptive_value associated with a single descriptive_category.
#   These represent the variables in the margins of the paper survey tables, e.g. Strategy or 
#   Regimen.  If the domain of regimens is different between tables, a separate descriptive 
#   category is necessary, e.g. child_regimen vs. adult_regimen.  Values for these are validated
#   within the indicated domain.
# 
# The method for updating all values for a location and date_period currently is to pass a hash of 
# csv_header keys to tally values to the class method:
#
#   create_or_replace_records_by_location_and_date_period_and_user_from_data_entry_group
#
# The hash is intended to become a 'DataEntryGroup' record which will track each data entry session separately.  
# Each csv_header key is structured as a string containing one possible combination of descriptive values, 
# separated with commas.
# 
# TODO: Ordinarily values for all possible combinations of all descriptive categories are expected for a 
# particular location and date period, but the model can indicate category combinations to be excluded 
# from the required combinations, for example the combination of "Polio (Newborn)" and "12-23 Months" 
# should be excluded from the child immunization tallies. 
# 

module ActsAsStatTally
  def self.included(base)
    base.send(:acts_as_visit_model)
    base.send :extend, ClassMethods
    base.send :include, InstanceMethods

    base.class_eval do
      belongs_to :health_center
      belongs_to :created_by, :class_name => 'User'
      belongs_to :updated_by, :class_name => 'User'
      validates_presence_of :health_center
      alias_method_chain :validate, :descriptive_categories
      
      named_scope :all_by_location_and_date_period, lambda { |l, d| { :conditions => { :health_center_id => l, :date_period => d } } } 
    end
  end

  module InstanceMethods
    def validate_with_descriptive_categories
      self.class._categories.each do |name, category_code|
        if self.send("#{name}_id_changed?") && v = self.send(name)
          if v.descriptive_category_code != category_code
            errors.add(name, "must be in category #{DescriptiveCategory.find_by_code(category_code).label}")
          end
        end
      end
      
      validate_without_descriptive_categories
    end
    
    def dimensions_label
      (self.class.category_names.map { |n| self.send(n).label } + self.class.dimensions.map { |k,v| self.send(k.to_s + '_code').to_s }).join(",")
    end

    def dimensions_code
      (self.class.category_names.map { |n| self.send(n).code } + self.class.dimensions.map { |k,v| self.send(k.to_s + '_code').to_s }).join(",")
    end
  end
  
  module ClassMethods
    def _categories
      @categories ||= []
    end
    
    def category_names
      _categories.map(&:first)
    end
    
    def indicators(ids)
      @indicators = ids
    end
    
    def new_from_keys_and_dimensions_and_user(keys, dimensions, user)
      dimensions = dimensions.split(/\ *,\ */)
      category_values = dimensions.slice!(0, _categories.length)

      vals = Hash[*_categories.zip(category_values).map { |cc, v| 
        name, code = *cc
        [name, DescriptiveValue.find_by_category_code_and_code(code, v)]
      }.flatten]
      
      vals = vals.merge Hash[*dimension_fields.map { |d| d.to_s + '_code' }.zip(dimensions).flatten]

      new(key_hash(keys).merge({ :created_by => user, :updated_by => user }.merge(vals)))
    end
    
    def key_fields
      [:health_center_id, :date_period]
    end
    
    def key_hash(key_values)
      Hash[*key_fields.zip(key_values).flatten]
    end
    
    def records_by_dimensions_for_keys(*keys)
      Hash[*find(:all, :conditions => key_hash(keys.flatten)).map { |t|
        [t.dimensions_code, t]
      }.flatten]
    end

    def records_by_param_names_for_keys(*keys)
      Hash[*find(:all, :conditions => key_hash(keys.flatten)).map { |t|
        if value_fields.length > 1
          value_fields.map do |tf|
            [t.dimensions_code + ':' + tf.to_s, t]
          end
        else
          [t.dimensions_code, t]
        end
      }.flatten]
    end
    
    def value_field(param_name)
      parse_header(param_name).last
    end
 
    def parse_header(k)
      k = k.gsub(/, */, ',')
      d, v = k.split(':', 2)
      if v.blank? 
        v = value_fields.first
      end
            
      return d, v
    end
    
    def create_or_replace_records_by_keys_and_user_from_data_entry_group(keys, user, data_entry_group)
      records = records_by_dimensions_for_keys(keys)
      
      errors = {}
      
      data_entry_group.reject { |k,v| k.ends_with?('/NR') }.each do |k, v|
        dimensions, value = parse_header(k)

        records[dimensions] ||= new_from_keys_and_dimensions_and_user(keys, dimensions, user)        

        if v.blank? && data_entry_group[k + '/NR'].to_s != '1'
          if !records[dimensions].new_record?
            records.delete(dimensions).delete()
          end
        else
          v = nil if v.to_s.strip.upcase == 'NR' || v.blank?
  
          records[dimensions].update_attributes(value => v, :updated_by => user) if v.to_s != records[dimensions][value].to_s
  
          records[dimensions].save
  
          errors[k] = records[dimensions].errors unless records[dimensions].errors.empty?
        end
      end
      
      return records, errors
    end    
    
    def exclude_combination(combination={})
      @exclusions ||= []
      @exclusions << combination
    end

    def expected_entries
      @expected ||= hashes_of_all_possible_category_values.reject { |c| category_excluded?(c) }
    end
    
    def hashes_of_all_possible_category_values
      # multicross is the cartesian product through multiple dimensions, so:
      # Enumerable.multicross([1,2],['a','b'],[:x]) == 
      #   [[1,'a',:x], [2,'a',:x], [1,'b',:x], [2,'b',:x]] 

      # this produces a list of hashes, for example:
      # [{:sex=>"Female", :strategy=>"Health Center"}, 
      #  {:sex=>"Male",   :strategy=>"Health Center"}, 
      #  {:sex=>"Female", :strategy=>"Mobile Brigade"}, 
      #  {:sex=>"Male",   :strategy=>"Mobile Brigade"}]

      # you should add a tally, a location, a date period and a user to each of these to make them 
      # complete database records.

      possible_values = Enumerable.multicross(*(category_names + dimension_fields).map { |f| possible_key_values(f) })

      possible_values.map { |v| Hash[*v.flatten] }
    end

    def category_excluded?(category_hash)
      @exclusions ||= []
      @exclusions.any? { |excluded_hash| 
        category_hash.values_at(*excluded_hash.keys) == excluded_hash.values_at(*excluded_hash.keys) 
      }
    end
    
    def descriptive_category(sym, options = {})
      dc_code = options[:category_code] || sym.to_s
      
      belongs_to sym, :class_name => 'DescriptiveValue'
      validates_presence_of sym
      
      _categories << [sym, dc_code]
    end

    def date_key_field *args
      if args.empty?
        @date_key_field || 'date_period'
      else
        @date_key_field = args.first
        validates_presence_of @date_key_field
      end
    end

    def string_key_field *args
      if args.empty?
        @string_key_field || []
      else
        @string_key_field = args.first
        validates_presence_of @string_key_field
      end
    end

    def tally_fields *args
      if args.empty?
        (@tally_fields || [])
      else
        @tally_fields = args
        @tally_fields.each do |t|
          validates_numericality_of t, { :only_integer => true, :greater_than_or_equal_to => 0, :allow_nil => true }
        end
      end
    end

    def date_fields *args
      if args.empty?
        (@date_fields || []) || []
      else
        @date_fields = args
      end
    end

    def dimensions args={}
      if args.empty?
        @dimensions || {}
      else
        @dimensions = args
        args.each do |n, d|
          belongs_to n, :class_name => d.class_name
        end
      end
    end

    def fields
      tally_fields.map { |f| [f, :tally] } +
        _categories.map { |c| [c.first, :descriptive_category] } +
        dimensions.map { |k, v| [k, :dimension] } +
        date_fields.map { |d| [d, :date] } +
        [date_key_field].map { |k| [k, :date_key] } +
        [string_key_field].map { |k| [k, :string_key] }
    end

    def fields_hash
      @fields_hash ||= Hash[*fields.flatten]
    end

    def fields_position
      @fields_position ||= Hash[*fields.map(&:first).map_with_index { |f, i| [f,i] }.flatten]
    end

    def value_fields
      tally_fields + date_fields
    end

    def dimension_fields
      dimensions.keys
    end

    def define_form_table(name, rows, cols)
      @form_tables ||={}
      @form_tables[name] = [rows, cols]
    end

    def form_table(name)
      @form_tables[name]
    end

    def descriptive_category_code(dim)
      cc = _categories.detect { |c| c.first == dim }
      cc.last if cc.present?
    end

    def dimension_code(cat)
      cc = _categories.detect { |c| c.last == cat }
      cc.first if cc.present?
    end
    
    def possible_key_values(dim)
      case fields_hash[dim]
      when :tally, :date
        [[dim, dim.to_s]]
      when :descriptive_category
        DescriptiveCategory.find_by_code(descriptive_category_code(dim)).descriptive_values.sort.map { |v| [dim, v.code] }
      when :dimension
        dimensions[dim].all.sort.map { |v| [dim, v.code] }
      end
    end

    def header_for(dim, value)
      code = case fields_hash[dim]
            when :tally, :date
              I18n.t("#{class_name}.#{dim}")
            when :descriptive_category
              I18n.t("DescriptiveValue.#{value}")
            when :dimension
              I18n.t("#{dimensions[dim].class_name}.#{value}")
            end
    end

    def tally_name
      self.name.titleize.capitalize.gsub(/\ tally$/, '').pluralize
    end

    def values_and_dimensions(point)
      point.partition { |v| [:tally, :date].include?(fields_hash[v.first]) }
    end

    def value_type(point)
      values, dimensions = values_and_dimensions(point)
      if values.length > 0 
        return fields_hash[values[0][0]]
      else
        return :tally
      end
    end

    def expected_params(name=:standard)
      row_groups, col_groups = form_table(name)

      col_group_combinations = col_groups.map { |cg| Enumerable.multicross(*cg.map { |col| possible_key_values(col) }) }.inject { |a,b| a + b }
      row_group_combinations = row_groups.map { |cg| Enumerable.multicross(*cg.map { |row| possible_key_values(row) }) }.inject { |a,b| a + b }
      
      row_group_combinations.map { |rg|        
        col_group_combinations.map { |cg|
          unless category_excluded?(Hash[*(rg + cg).flatten])            
            [param_name(rg + cg), value_type(rg + cg)]
          end
        }
      }.flatten_once.compact
    end

    def param_name(point)
      values, dimensions = values_and_dimensions(point)
      sorted = dimensions.sort_by { |t, v| fields_position[t] }.map(&:last)
      raise "Multiple value fields" if values && values.length > 1 
      sorted.join(",") + (values.empty? ? '' : ':' + values.first.last.to_s)
    end

    def screens
      [table_name.singularize]
    end
    
    def process_data_submission(visit, params)
      slice = name.underscore
      
      records, errors = create_or_replace_records_by_keys_and_user_from_data_entry_group(
        [visit.health_center_id, visit.epi_month], 
        visit.field_coordinator, params[slice])
      
      errors
    end

    def visit_json(visit)
      record_value_hash = records_by_param_names_for_keys(visit.health_center, visit.epi_month)
      expected_params().inject({}) { |hash, (param, type)|
        if r = record_value_hash[param]
          v = r.send(value_field(param))
          hash[param_to_jquery(param)] = { 'value' => v.to_s, 'nr' => v.nil? ? 'true' : 'false' }
        else
          hash[param_to_jquery(param)] = { 'value' => '', 'nr' => '' }
        end

        hash
      }
    end

    def xforms_group_name
      'stat_tally'
    end

    def visit_navigation_category
      'epi'
    end

    def depends_on_visit?
      false
    end
    
    def odk_to_params(xml)
      nil
    end

    def xforms_to_params(xml)
      Hash[*xml.xpath("/olmis/#{table_name}/item").map { |n|
        [n['for'].to_s, n['val'].to_s] +
          (n['nr'].to_s == "true" ? [n['for'].to_s + '/NR', 1] : [])
      }.flatten]
    end

    def json_to_params(json)
      json[table_name.singularize].inject({}) { |hash, (key, value)|
        fixed_key = param_from_jquery(key)

        hash[fixed_key] = value['value']
        hash["#{fixed_key}/NR"] = 1 if value['nr'] # NOTE: value['nr'] should come in as a boolean, not a string
        hash
      }
    end

    def progress_query(date_periods)    
      <<-TALLY
        select health_center_visits.id as id,
          health_center_visits.visit_month as date_period,
          #{expected_entries.length} as expected_entries,
          '#{table_name.singularize}' as screen,
          count(distinct #{table_name}.id) as entries
        from health_center_visits 
          left join #{table_name} on 
            #{table_name}.health_center_id = health_center_visits.health_center_id
            and #{table_name}.date_period = #{previous_date_period_sql('health_center_visits.visit_month')}
        where health_center_visits.visit_month in (#{date_periods})
        group by health_center_visits.id 
      TALLY
    end

    private

    def previous_date_period_sql(dp)
      "date_format((date(concat(#{dp}, '-01')) - interval 1 month), '%Y-%m')"
    end    

    # NOTE: param_to_jquery and param_from_jquery are copied from OlmisHelper
    # because the OlmisHelper methods are not accessible from here. Do not change
    # these methods without also changing them in OlmisHelper.

    # Convert reserved meta characters to safe characters; used when generating data for offline use.
    def param_to_jquery(str)
      str.tr(':,', '%-')
    end

    # Reverse the action of #param_to_jquery; used when parsing data from an offline data submission.
    def param_from_jquery(str)
      str.tr('%-', ':,')
    end
  end
end
