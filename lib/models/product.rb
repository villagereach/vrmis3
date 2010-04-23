# == Schema Information
# Schema version: 20100419182754
#
# Table name: products
#
#  id              :integer(4)      not null, primary key
#  code            :string(255)     not null
#  product_type_id :integer(4)      not null
#  position        :integer(4)      default(0), not null
#  created_at      :datetime
#  updated_at      :datetime
#

class Product < ActiveRecord::Base
  include BasicModelSecurity

  has_many :packages
  belongs_to :product_type

  validates_presence_of :code
  referenced_by :code
  
  def label
    I18n.t("Product.#{code}")
  end

  alias_method :name, :label

  begin
    ProductType.active.each do |type|
      named_scope type.code, { :include => :product_type, :conditions => { 'product_types.code' => type.code } }
    end
  rescue ActiveRecord::StatementInvalid => e
        
  end
  
  named_scope :trackable, { :include => :product_type, :conditions => { 'product_types.trackable' => true } }
  named_scope :active, { :conditions => { 'active' => true } }

  include Comparable
  def <=>(other)
    [product_type, position] <=> [other.product_type, other.position]
  end

  def report_series_options
    { :column_group => type_label }
  end

  def label_without_type
    label.gsub(/\s+\Q#{type_label}\E$/i,'')
  end

  def type_label
    product_type.label
  end
end
