# == Schema Information
# Schema version: 20100419182754
#
# Table name: descriptive_values
#
#  id                      :integer(4)      not null, primary key
#  descriptive_category_id :integer(4)      not null
#  code                    :string(255)     not null
#  position                :integer(4)      default(0), not null
#  created_at              :datetime
#  updated_at              :datetime
#

class DescriptiveValue < ActiveRecord::Base
  include BasicModelSecurity

  belongs_to :descriptive_category
  referenced_by :code

  include Comparable
  def <=>(other)
    position <=> other.position
  end
  
  def label
    I18n.t("DescriptiveValue.#{code}")
  end
  
  def self.find_all_by_category_code(c)
    find_all_by_descriptive_category_id(DescriptiveCategory.find_by_code(c))
  end
  
  def self.find_by_category_code_and_code(c, v)
    find_by_descriptive_category_id_and_code(DescriptiveCategory.find_by_code(c), v)    
  end
end


