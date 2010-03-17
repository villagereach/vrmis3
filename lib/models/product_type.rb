class ProductType < ActiveRecord::Base
  unloadable

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

