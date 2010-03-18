# == Schema Information
# Schema version: 20100127014005
#
# Table name: roles
#
#  id           :integer(4)      not null, primary key
#  name         :string(255)     not null
#  created_at   :datetime
#  updated_at   :datetime
#  landing_page :string(255)
#

class Role < ActiveRecord::Base
  unloadable
  
  include BasicModelSecurity
  has_many :users
  referenced_by :code

  def label
    code.humanize
  end

  include Comparable
  def <=>(other)
    code <=> other.code
  end
  
  def report_format
    if code == 'field_coordinator'
      'fc'
    else
      ''
    end    
  end
end


