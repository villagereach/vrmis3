# == Schema Information
# Schema version: 20100521181503
#
# Table name: warehouse_visits
#
#  id           :integer(4)      not null, primary key
#  warehouse_id :integer(4)      not null
#  visit_month  :string(255)     not null
#  request_id   :integer(4)      not null
#  pickup_id    :integer(4)      not null
#  created_at   :datetime
#  updated_at   :datetime
#

class WarehouseVisit < ActiveRecord::Base
  belongs_to :warehouse

  has_one :request, :class_name => 'Inventory'
  has_one :pickup,  :class_name => 'Inventory'

  has_and_belongs_to_many :data_submissions, :order => 'created_at desc'
  
  validates_presence_of :warehouse_id
  validates_presence_of :request, :pickup

  named_scope :recent, lambda{|count| { :order => 'updated_at DESC', :limit => count } }

  attr_accessor :request, :pickup, :date
  
  def request
    @request ||= find_or_initialize_inventory(request_id, 'DeliveryRequest')
  end

  def pickup
    @pickup ||= find_or_initialize_inventory(pickup_id, 'DeliveryPickup')
  end

  def date
    @date ||= pickup.date
  end

  def to_json
    packages = Package.active
    [ request, pickup ].inject({}) do |hash, inventory|
      hash[inventory.inventory_type] = inventory.new_record? \
        ? Hash[*packages.map {|p| [ p.code, '' ]}.flatten] \
        : Hash[*inventory.package_counts.map {|pc| [ pc.package.code, pc.quantity ]}.flatten]
      hash
    end.merge({ :date => '' }).to_json
  end

  protected

  def before_save
    self.request_id = @request.id
    self.pickup_id  = @pickup.id
  end

  private

  def find_or_initialize_inventory(id, type)
    Inventory.find_by_id(id) ||
      Inventory.find_or_initialize_by_date_and_stock_room_id_and_inventory_type(
        @date, self.warehouse ? self.warehouse.stock_room.id : nil, type)
  end

end
