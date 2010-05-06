module ActsAsVisitModel
  def self.included(base)
    base.send :extend, ClassMethods
    base.send :include, InstanceMethods
  end
  
  module InstanceMethods
  end
  
  module ClassMethods
    def screens
      [xforms_group_name]
    end

    def odk_to_params(xml)
      nil
    end

    def xforms_to_params(xml)
      nil
    end

    def web_to_params(params)
      params[table_name.singularize]
    end
    
    def json_to_params(params)
      params[xforms_group_name]
    end
    
    def xforms_group_name
      table_name.singularize
    end

    def visit_json(visit)
      {}
    end

    def process_data_submission(visit, params)
      nil
    end

    def progress_query(date_periods)
      ""
    end

    def depends_on_visit?
      true
    end
    
    def visit_navigation_category
      'misc'
    end
  end
end
