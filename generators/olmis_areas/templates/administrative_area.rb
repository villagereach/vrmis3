class AdministrativeArea < ActiveRecord::Base
  include BasicModelSecurity
  referenced_by :code
  has_one :street_address, :as => 'addressed'
  
  has_many :direct_health_centers, :class_name => 'HealthCenter', :foreign_key => 'administrative_area_id'

  has_and_belongs_to_many :users
  has_many :warehouses
  
  belongs_to :parent, :class_name => 'AdministrativeArea'

  validates_numericality_of :population, :allow_nil => true, :integer => true
  
  def label
    I18n.t(self.class.name + '.' + code)
  end

  include Comparable
  def <=>(other)
    code <=> other.code
  end
  
  alias_method :name, :label

  def self.param_name
    name.tableize.singularize + '_id'
  end

  def self.stockout_table_options(options)
    {}
  end

  def self.options_for_select_by_parent(parent)
    all(:conditions => {:parent_id => parent}).map { |p| [p.label, p.id.to_s] }
  end

  def self.options_for_select
    all.sort.map { |p| [p.label, p.id.to_s] }
  end

  def fridges
    Fridge.scoped_by(:conditions => { :health_center => self.health_centers })
  end
  
  def centroid
    street_address.maybe.centroid
  end

  def self.sql_area_ids
    '<%= hierarchy.map { |h| h.tableize + ".id" }.join(", ") %>'
  end

  def self.sql_any_area(id)
    sanitize_sql_for_conditions(["? in (#{sql_area_ids})", id])
  end

  def self.sql_area_join
    <% pairs = (hierarchy.reverse + [nil]).zip([['HealthCenter', 'administrative_area_id']] + hierarchy.reverse.map { |h| [h, 'parent_id'] })[0..-2] %>
    <<-SQL
    <%= pairs.map { |p, cp| c, cid = *cp; "administrative_areas #{p.tableize} on #{p.tableize}.id = #{c.tableize}.#{cid}" }.join("\n    inner join ") %>
    SQL
  end

  <% hierarchy.each do |h| %>
  def <%= h.underscore %>
    parent.<%= h.underscore %> if parent
  end
  <% end %>

  <% hierarchy.first do |h| %>
  def <%= h.underscore %>
    <%= h %>.first
  end
  <% end %>

  <% hierarchy[1..-1].each do |h| %>
  def self.<%= h.tableize %>
    <%= h %>.all.sort.map(&:label)
  end
  <% end %>

  def delivery_zones
    health_centers.map(&:delivery_zone).uniq
  end
end

