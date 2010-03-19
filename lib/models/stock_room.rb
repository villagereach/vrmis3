# == Schema Information
# Schema version: 20100127014005
#
# Table name: stock_rooms
#
#  id         :integer(4)      not null, primary key
#  created_at :datetime
#  updated_at :datetime
#

class StockRoom < ActiveRecord::Base
  unloadable

  include BasicModelSecurity

  referenced_by :health_center_code

  has_many :equipment_counts
  has_many :equipment_statuses
  has_many :fridges
  has_many :fridge_statuses
  has_many :stock_card_statuses
  
  has_one :health_center
  has_one :warehouse

  has_many :ideal_stock_amounts
  
  def self.find_by_health_center_code(name)
    HealthCenter.find_by_code(name).maybe.stock_room
  end

  def health_center_code
    health_center.code
  end
  
  def name
    (health_center || warehouse).name
  end
  
  def self.grouped_options_for_select
    [['Warehouses', Warehouse.all(:include => :administrative_area, :order => 'administrative_areas.code').
                             map { |w| [w.code, w.stock_room_id] }],
     ['Health Centers', HealthCenter.all(:order => 'code').map { |h| [h.code, h.stock_room_id] }]]
  end

  def ideal_stock_by_package
    Hash[*IdealStockAmount.all(:select => "package_id, ideal_stock_amounts.quantity",
      :conditions => { :stock_room_id => id }).map{ |i| [i.package, i.quantity] }.flatten]
  end

  def package_counts_by_package
    package_hash = {}
    Package.all.each do |p|
      package_hash[p] = IdealStockAmount.find_by_package_id_and_stock_room_id(p.id, id).maybe.quantity
    end    
    package_hash 
  end
  

  def place
    health_center || warehouse
  end
  
  def administrative_area
    place.administrative_area
  end
  
  def district
    administrative_area.district
  end
  
  def province
    administrative_area.province
  end
  
  def after_save
    ideal_stock_amounts.each(&:save)
  end
end


