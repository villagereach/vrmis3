# == Schema Information
# Schema version: 20100205183625
#
# Table name: rdts
#
#  id         :integer(4)      not null, primary key
#  name       :string(255)     not null
#  position   :integer(4)      default(0), not null
#  product_id :integer(4)      not null
#  code       :string(255)     not null
#  created_at :datetime
#  updated_at :datetime
#

class Rdt < ActiveRecord::Base
  include BasicModelSecurity

  belongs_to :product

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_presence_of :product_id

  referenced_by :code

  def label
    self.class.human_attribute_name(name, :default => name)
  end

  include Comparable
  def <=>(other)
    position <=> other.position
  end  
end
