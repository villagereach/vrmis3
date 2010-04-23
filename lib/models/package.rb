# == Schema Information
# Schema version: 20100419182754
#
# Table name: packages
#
#  id         :integer(4)      not null, primary key
#  code       :string(255)     default(""), not null
#  quantity   :integer(4)      default(0)
#  product_id :integer(4)      not null
#  position   :integer(4)      default(0), not null
#  created_at :datetime
#  updated_at :datetime
#

class Package < ActiveRecord::Base
  include BasicModelSecurity

  belongs_to :product
  referenced_by :code

  validates_presence_of :code
  validates_presence_of :product_id
  validates_numericality_of :quantity, :only_integer => true, :greater_than => 0, :allow_nil => true

  named_scope :trackable, { :include => { :product => :product_type }, :conditions => { 'product_types.trackable' => true } }
  named_scope :active, { :conditions => { 'active' => true } }
  
  include Comparable
  def <=>(other)
    position <=> other.position
  end

  def inventoried_by_type?(t, screen)
    true
  end
  
  def self.inheritance_column
    ''
  end

  def label
    I18n.t("Package.#{code}");
  end
end


