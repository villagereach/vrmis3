class <%= class_name %> < ActiveRecord::Base
  acts_as_stat_tally

  string_key_field :date_period

  <% if tally_fields.present? %>
  tally_fields <%= tally_fields.map { |f| ':'+f }.join(', ') %>
  <% end %>
  
  <% if date_fields.present? %>
  date_fields <%= date_fields.map { |f| ':'+f }.join(', ') %>
  <% end %>

  <% descriptive_categories.each do |f, options| %>
  descriptive_category :<%= f %>, <%= options.map { |k, v| ":#{k} => '#{v}'" }.join(', ') %>
  <% end %>

    <% if dimensions.present? 
    dims = dimensions.map { |f|  
      if f =~ /\.(.*)/
        method = $1
      else
        method = f
      end
      ":#{method} => #{f}"
    }
    %>
    dimensions <%= dims.join(', ') %>
  <% end %>
  
  <% exclude_combinations.each do |e| %>
  exclude_combination <%= e.map { |k, v| ":#{k} => '#{v}'" }.join(", ") %>
  <% end %>
  
  <% form_tables.each do |f, h| %>
  define_form_table :<%= f %>, <%= h['row_groups'].map { |rg| rg.map(&:to_sym) }.inspect %>, <%= h['column_groups'].map { |cg| cg.map(&:to_sym) }.inspect %>
  <% end %>  
end

