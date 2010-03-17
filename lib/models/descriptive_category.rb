# == Schema Information
# Schema version: 20100127014005
#
# Table name: descriptive_categories
#
#  id          :integer(4)      not null, primary key
#  code        :string(255)     not null
#  label       :string(255)     not null
#  description :text
#  created_at  :datetime
#  updated_at  :datetime
#

class DescriptiveCategory < ActiveRecord::Base
  unloadable

  include BasicModelSecurity

  referenced_by :code
  has_many :descriptive_values

  def label
    I18n.t("DescriptiveCategory.#{code}")
  end
  
  def value_labels
    descriptive_values.map(&:label)
  end
end


