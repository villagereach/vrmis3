class <%= class_name %> < AdministrativeArea
  include BasicModelSecurity

  <% if parent_class %>
  belongs_to :<%= parent_class.tableize.singularize %>, :foreign_key => 'parent_id', :class_name => '<%= parent_class %>'

  named_scope :in_<%= parent_class.tableize.singularize %>, lambda{|<%= parent_class.tableize.singularize %>| { :conditions => [ 'parent_id = ?', <%= parent_class.tableize.singularize %> ] } }
  <% end %>
  
  <% if child %>
  has_many :<%= child.tableize %>, :foreign_key => 'parent_id', :class_name => '<%= child %>'
  alias_method :regions, :<%= child.tableize %>
  
  def health_centers
    direct_health_centers + <%= child.tableize %>.map(&:health_centers).flatten
  end
  <% else %>
  has_many :health_centers, :foreign_key => 'administrative_area_id'
  alias_method :regions, :health_centers
  <% end %>

  def <%= table_name.singularize %>
    self
  end
  
  <% if default %>
  def <=>(other)
    (code == '<%= default %>' && other.code != code) ? -1 : super
  end
  <% end %>
    
  def self.default
    <% if default %>find_by_code('<%= default %>')
    <% else %>first(:order => 'code')
    <% end %>
  end
end


