# == Schema Information
# Schema version: 20100127014005
#
# Table name: ideal_stock_amounts
#
#  id            :integer(4)      not null, primary key
#  stock_room_id :integer(4)      not null
#  package_id    :integer(4)      not null
#  quantity      :integer(4)      default(0), not null
#  created_at    :datetime
#  updated_at    :datetime
#

class IdealStockAmount < ActiveRecord::Base
  include BasicModelSecurity
  belongs_to :package
  belongs_to :stock_room
  validates_numericality_of :quantity, { :only_integer => true, :greater_than_or_equal_to => 0 }
  
  def to_label
    "#{stock_room.name}: #{package_name}"
  end
end


