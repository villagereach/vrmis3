class AdministrativeArea < ActiveRecord::Base
  unloadable

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

  def delivery_zones
    health_centers.map(&:delivery_zone).uniq
  end

  Olmis.area_hierarchy.each do |h|
    define_method h.underscore do
      parent.send(h.underscore) if parent
    end
  end

  class << self
    def sql_area_ids
      Olmis.area_hierarchy.map { |h| h.tableize + ".id" }.join(", ")
    end
  
    def sql_any_area(id)
      sanitize_sql_for_conditions(["? in (#{sql_area_ids})", id])
    end
  
    def sql_area_join
      hierarchy = Olmis.area_hierarchy
      pairs = (hierarchy.reverse + [nil]).zip([['HealthCenter', 'administrative_area_id']] + hierarchy.reverse.map { |h| [h, 'parent_id'] })[0..-2]
      pairs.map { |p, cp| c, cid = *cp; "administrative_areas #{p.tableize} on #{p.tableize}.id = #{c.tableize}.#{cid}" }.join("\n    inner join ")
    end

    Olmis.area_hierarchy.first do |h|
      define_method h.underscore do
        h.constantize.first
      end
    end
  
    Olmis.area_hierarchy.each do |h|
      define_method h.tableize do
        h.constantize.all.sort.map(&:label)
      end
    end
  end
end
