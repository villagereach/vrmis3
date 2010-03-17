# == Schema Information
# Schema version: 20100205183625
#
# Table name: packages
#
#  id         :integer(4)      not null, primary key
#  name       :string(255)     not null
#  quantity   :integer(4)      default(0)
#  product_id :integer(4)      not null
#  position   :integer(4)      default(0), not null
#  code        :string(255)     default(""), not null
#  created_at :datetime
#  updated_at :datetime
#

class Package < ActiveRecord::Base
  unloadable

  include BasicModelSecurity

  belongs_to :product
  referenced_by :code

  validates_presence_of :code
  validates_presence_of :product_id
  validates_numericality_of :quantity, :only_integer => true, :greater_than => 0, :allow_nil => true

  named_scope :trackable, { :include => { :product => :product_type }, :conditions => { 'product_types.trackable' => true } }
  
  include Comparable
  def <=>(other)
    position <=> other.position
  end
  
  def self.inheritance_column
    ''
  end

  def label
    I18n.t("Package.#{code}");
  end
end


