class <%= migration_filename.camelize %> < ActiveRecord::Migration
  def self.up
    <%- if drop_old_table -%>
    drop_table '<%= table_name %>'
    <%- end -%>create_table '<%= table_name %>' do |t|
      t.references 'health_centers', :null => false
      t.string   'date_period',      :null => false

      <% tally_fields.each do |f| %>
        t.integer  '<%= f %>'
      <% end %>

      <% date_fields.each do |f| %>
        t.date  '<%= f %>'
      <% end %>

      <% descriptive_categories.each do |f, options| %>
        t.integer  '<%= f %>_id', :null => false, :references => :descriptive_values
      <% end %>

      <% dimensions.each do |f| %>
      <%-
        data = f.split('.')
        if data.length > 1
          method = data.last
          relation = data.first.tableize
        else
          method = data[0]
          relation = data[0].tableize
        end
        %>
        t.integer '<%= method.singularize %>_id', :null => false, :references => :<%= relation %>
      <% end %>

      t.integer  'created_by_id', :references => 'users'
      t.integer  'updated_by_id', :references => 'users'
      t.timestamps
    end

    add_index '<%= table_name %>', ['health_center_id', 'date_period'], :name => 'idx_<%= table_name %>_aa_dp'
  end

  def self.down
    drop_table '<%= table_name %>'
  end
end
