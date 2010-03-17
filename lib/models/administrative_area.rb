class ::AdministrativeArea < ActiveRecord::Base
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

  
  def country
    parent.country if parent
  end
  
  def province
    parent.province if parent
  end
  
  def district
    parent.district if parent
  end
  

  

  
  def self.provinces
    Province.all.sort.map(&:label)
  end
  
  def self.districts
    District.all.sort.map(&:label)
  end
  

  def delivery_zones
    health_centers.map(&:delivery_zone).uniq
  end
end

