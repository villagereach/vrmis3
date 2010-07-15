module ActionView
  module Helpers
    class FormBuilder
      def text_field_with_html5(name, options={})
        if options.has_key?(:type) 
          text_field_without_html5(name, options).gsub('type="text"', 'type="'+options[:type]+'"')
        else
          text_field_without_html5(name, options)
        end
      end
      
      alias_method_chain :text_field, :html5
    end
  end
end
