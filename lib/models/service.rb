# == Schema Information
# Schema version: 20100127014005
#
# Table name: services
#
#  id         :integer(4)      not null, primary key
#  name       :string(255)     not null
#  position   :integer(4)      default(0), not null
#  product_id :integer(4)      not null
#  created_at :datetime
#  updated_at :datetime
#  code       :string(255)     not null
#

class Service < ActiveRecord::Base
  unloadable

  include BasicModelSecurity

  belongs_to :product

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_presence_of :product_id

  referenced_by :code

  include Comparable
  def <=>(other)
    position <=> other.position
  end
    
  def label
    name
  end

end


