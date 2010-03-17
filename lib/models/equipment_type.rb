# == Schema Information
# Schema version: 20100127014005
#
# Table name: equipment_types
#
#  id         :integer(4)      not null, primary key
#  name       :string(255)     not null
#  position   :integer(4)      default(0), not null
#  created_at :datetime
#  updated_at :datetime
#

class EquipmentType < ActiveRecord::Base
  unloadable
 
  include BasicModelSecurity

  validates_presence_of :code
  validates_uniqueness_of :code
  referenced_by :code
  
  include Comparable
  def <=>(other)
    position <=> other.position
  end
  
  def label
    I18n.t("EquipmentType.#{code}");
  end
end


