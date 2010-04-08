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
  unloadable

  belongs_to :stock_room
  belongs_to :user
  
  has_many :package_counts

  validates_presence_of :stock_room_id
  validates_presence_of :user_id
  validates_presence_of :date
  validates_presence_of :inventory_type
  validates_uniqueness_of :date, :scope=>[:stock_room_id, :inventory_type]
  validates_associated :package_counts

  def package_count_quantity_by_package
    Hash[*package_counts_by_package.map { |pkg, count| [pkg, count.quantity] }.flatten]
  end

  def package_counts_by_package_code
    Hash[*package_counts_by_package.map { |pkg, count| [pkg.code, count] }.flatten]
  end
  
  protected

  def package_counts_by_package(package_options={})
    pc_hash = Hash[*package_counts.map { |pc| [pc.package, pc] }.flatten]
    
    Package.all(package_options).each do |p|
      pc_hash[p] ||= package_counts.build(:package => p, :quantity => nil)
      pc_hash[p].inventory = self
    end
    
    pc_hash
  end
end


