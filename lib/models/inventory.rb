# == Schema Information
# Schema version: 20100205183625
#
# Table name: inventories
#
#  id             :integer(4)      not null, primary key
#  stock_room_id  :integer(4)      not null
#  date           :date            not null
#  inventory_type :string(255)     not null
#  user_id        :integer(4)      not null
#  created_at     :datetime
#  updated_at     :datetime
#

class Inventory < ActiveRecord::Base
  belongs_to :stock_room
  belongs_to :user
  
  has_many :package_counts

  def package_counts_by_package(return_package_hash=false)
    pc_hash = Hash[*package_counts.map { |pc| [pc.package_code, pc] }.flatten]
    package_hash = {}
    Package.all.each do |p|
      pc_hash[p.code] ||= package_counts.build(:package => p, :quantity => nil)
      package_hash[p] = pc_hash[p.code].maybe.quantity
    end    
    return_package_hash ? package_hash : pc_hash
  end

  validates_presence_of :stock_room_id
  validates_presence_of :user_id
  validates_presence_of :date
  validates_presence_of :inventory_type
  validates_uniqueness_of :date, :scope=>[:stock_room_id, :inventory_type]
  validates_associated :package_counts
end


