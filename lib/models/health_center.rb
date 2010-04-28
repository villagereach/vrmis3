# == Schema Information
# Schema version: 20100419182754
#
# Table name: health_centers
#
#  id                     :integer(4)      not null, primary key
#  code                   :string(255)     default(""), not null
#  description            :text            default(""), not null
#  stock_room_id          :integer(4)      not null
#  delivery_zone_id       :integer(4)      not null
#  administrative_area_id :integer(4)      not null
#  created_at             :datetime
#  updated_at             :datetime
#  catchment_population   :integer(4)
#

class HealthCenter < ActiveRecord::Base
  include BasicModelSecurity
  include ActsAsCoded
  
  has_one :street_address, :as => 'addressed'
  
  belongs_to :administrative_area
  belongs_to :delivery_zone

  belongs_to :stock_room
  has_many :fridges, :through => :stock_room

  has_many :health_center_visits, :order => 'visited_at desc'

  has_many :ideal_stock_amounts, :foreign_key => 'stock_room_id', :primary_key => 'stock_room_id'
  has_many :inventories, :foreign_key => 'stock_room_id', :primary_key => 'stock_room_id'

  has_and_belongs_to_many :users
  
  def label
    I18n.t("HealthCenter.#{code}")
  end

  alias_method :name, :label

  named_scope :with_ideal_stock, { :include => {:ideal_stock_amounts => {:package => :product}} }
  
  RecentInventory = 'product_types.trackable and package_counts.package_id = ideal_stock_amounts.package_id and ideal_stock_amounts.quantity > 0 and inventories.date >= ?'
  
  named_scope :with_recent_delivery, lambda { |r| {
    :include => [:ideal_stock_amounts, { :inventories => { :package_counts => { :package => { :product => :product_type } } } }],
    :conditions => ['inventory_type = "DeliveredHealthCenterInventory" and '+RecentInventory, Date.today - r.months]
  } }

  named_scope :with_recent_existing, lambda { |r| {
    :include => [:ideal_stock_amounts, { :inventories => { :package_counts => { :package => { :product => :product_type } } } }],
    :conditions => ['inventory_type = "ExistingHealthCenterInventory" and  '+RecentInventory, Date.today - r.months]
  } }
  
  named_scope :recent_visits, lambda { |r| { 
    :include => :health_center_visits, 
    :conditions => ["health_center_visits.visit_status = 'Visited' and health_center_visits.visited_at >= ?", Date.today - r.months]
  } }

  named_scope :recent_ok_non_visits, lambda { |r| { 
    :include => :health_center_visits, 
    :conditions => ["health_center_visits.visit_status in (#{HealthCenterVisit::ExcusableNonVisitReasons.map { |e| "'#{e}'" }.join(', ')})"+
      "and health_center_visits.visit_month >= ?", (Date.today - r.months).to_date_period]
  } }
  
  def package_quantities_by_date
    #call me after with_recent_delivery or with_recent_existing to limit inventories to a date range and a single type
    Hash[*inventories.map { |i| 
      [i.date.to_date_period, Hash[*i.package_counts.map { |pc| [pc.package.code, pc.quantity] }.flatten]] 
    }.flatten]
  end
  
  def health_centers
    [self]
  end
  
  def self.param_name
    'health_center_id'
  end
  
  def primary_contact
    users.first
  end

  include Comparable
  def <=>(other)
    code <=> other.code
  end

  def self.stockout_table_options(options)
    {}
  end

  named_scope :in_delivery_zone, lambda{|delivery_zone|
    { :conditions => { :delivery_zone_id => delivery_zone } }
  }
  
  named_scope :in_district, lambda {|district|
    { :include => :administrative_area, :conditions => { 'administrative_areas.parent_id' => district } }
  }
  
  def ideal_stock_amounts_by_code()
    Hash[*ideal_stock_amounts.map { |i| [i.package_code, i.quantity] }.reject { |p, q| q.zero? }.flatten]
  end
  
  def self.options_for_select(args={})
    all(args.merge(:order => 'name')).map { |dz| [dz.name, dz.id] }
  end
  
  def visit_for_month(visit_month)
    health_center_visits.find_by_visit_month(visit_month)
  end
  
  def most_recent_visit
    health_center_visits.first
  end
  
  def most_recent_visit_with_any_inventory
    health_center_visits.find(:first, :conditions => <<-SQL)
      exists (select 1 from health_center_visit_inventory_groups 
                WHERE health_center_visit_id = health_center_visits.id 
                      AND (existing_quantity IS NOT NULL 
                       OR delivered_quantity IS NOT NULL))
    SQL
  end

  def field_coordinator
    delivery_zone.field_coordinator
  end

  def district
    administrative_area.district
  end
  
  def province
    administrative_area.province
  end

  def population
    administrative_area.population
  end

  def primary_contact_name
    street_address.name
  end

  def primary_contact_phone
    street_address.phone
  end
  
  report_column :update_link,   :sortable => false,                 :header => "headers.update_link",   :type => :link do |r| [I18n.t("edit"), [:edit, r] ] end
  report_column :name,          :sql_sort => 'health_centers.code', :header => "headers.health_center", :type => :link do |f| [f.name, f ] end
  report_column :health_center, :sql_sort => 'administrative_areas.code', :header => "headers.health_center" do |r| r.administrative_area.maybe.name end  
  report_column :delivery_zone, :sql_sort => 'delivery_zones.code',       :header => "headers.delivery_zone" do |r| r.delivery_zone.maybe.name end
  report_column :primary_contact_name,  :sortable => false, :header => "headers.primary_contact_name"  do |r| r.street_address.name end
  report_column :primary_contact_phone, :sortable => false, :header => "headers.primary_contact_phone" do |r| r.street_address.phone end
  report_column :district,      :sortable => false, :header => "headers.district" do |r| r.administrative_area.district.maybe.name end
  report_column :fridges,       :sortable => false, :header => "headers.fridges", :type => :links  do |hc| hc.stock_room.fridges.map { |f| [f.code, f] } end
  report_column :address,       :sortable => false, :header => "headers.address"                    do |hc| hc.street_address.to_s end  

  def visited_in?(dp)
    visits.any? { |v| v.visit_month == dp }
  end
  
  def visits
    health_center_visits.select { |hcv| hcv.visit_status == 'Visited' }.sort_by(&:visited_at)
  end
  
  def excusable_non_visits
    health_center_visits.select { |hcv| hcv.visit_status == 'health_center_closed' }.sort_by(&:visited_at)
  end
end


