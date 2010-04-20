# == Schema Information
# Schema version: 20100419182754
#
# Table name: delivery_zones
#
#  id           :integer(4)      not null, primary key
#  code         :string(255)
#  created_at   :datetime
#  updated_at   :datetime
#  warehouse_id :integer(4)      not null
#

class DeliveryZone < ActiveRecord::Base
  include BasicModelSecurity
  include ActsAsCoded
  
  has_many :health_centers, :order => 'code ASC'
  belongs_to :warehouse

  validates_presence_of :warehouse_id

  has_and_belongs_to_many :users
  
  def field_coordinator
    users.select(&:field_coordinator?).first
  end
  
  def label
    I18n.t("DeliveryZone.#{code}")
  end
  
  alias_method :name, :label
  
  include Comparable
  def <=>(other)
    label <=> other.label
  end
  
  def self.param_name
    'delivery_zone_id'
  end
  
  def refrigerators
    Fridge.find(:all, 
      :conditions => { :stock_room_id => health_centers.map(&:stock_room_id) },
      :include => :fridge_statuses)
    #stock_rooms.map(&:equipment).flatten.select(&:refrigerator?)
  end

  def regions
    health_centers.map(&:administrative_area).uniq
  end

  def total_ideal_stock_by_package
    Hash[*Package.trackable.all.map { |p| [p, nil] }.flatten].merge(
      Hash[*IdealStockAmount.all(:select => "package_id, sum(quantity) as quantity",
        :conditions => { :stock_room_id => health_centers.map(&:stock_room_id) }, 
        :group => 'package_id').map{ |i| [i.package, i.quantity] }.flatten]
    )
  end
end


