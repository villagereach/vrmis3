# == Schema Information
# Schema version: 20100127014005
#
# Table name: package_counts
#
#  id           :integer(4)      not null, primary key
#  inventory_id :integer(4)      not null
#  package_id   :integer(4)      not null
#  quantity     :integer(4)
#  created_at   :datetime
#  updated_at   :datetime
#

class PackageCount < ActiveRecord::Base
  unloadable

  belongs_to :inventory
  belongs_to :package

  def nr
    !new_record? && quantity.nil?
  end
  
  validates_presence_of :inventory_id
  validates_presence_of :package_id
  validates_numericality_of :quantity, :only_integer => true, :greater_than_or_equal_to => 0, :allow_nil => true
end


