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
  validates_presence_of :request_id
  validates_presence_of :pickup_id

  named_scope :recent, lambda{|count| { :order => 'updated_at DESC', :limit => count } }

  def request
    Inventory.find_by_id(request_id)
  end

  def pickup
    Inventory.find_by_id(pickup_id)
  end

  def to_json
    packages = Package.active
    visit_request = request || Inventory.new(:inventory_type => 'DeliveryRequest')
    visit_pickup  = pickup  || Inventory.new(:inventory_type => 'DeliveryPickup')
    [ visit_request, visit_pickup ].inject({}) do |hash, inventory|
      hash[inventory.inventory_type] = inventory.new_record? \
        ? Hash[*packages.map {|p| [ p.code, '' ]}.flatten] \
        : Hash[*inventory.package_counts.map {|pc| [ pc.package.code, pc.quantity ]}.flatten]
      hash
    end.merge({ :date => '' }).to_json
  end
end
