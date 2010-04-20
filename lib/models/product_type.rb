# == Schema Information
# Schema version: 20100419182754
#
# Table name: product_types
#
#  id        :integer(4)      not null, primary key
#  code      :string(255)     not null
#  position  :integer(4)      default(0), not null
#  trackable :boolean(1)      default(FALSE)
#

class ProductType < ActiveRecord::Base
  has_many :products
  referenced_by :code

  named_scope :trackable, { :conditions => { :trackable => true } }
  
  include Comparable
  def <=>(other)
    self.position <=> other.position
  end
  
  def label
    I18n.t("ProductType.#{code}");
  end  
end

