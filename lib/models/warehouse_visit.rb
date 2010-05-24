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
end
