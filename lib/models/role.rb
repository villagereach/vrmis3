# == Schema Information
# Schema version: 20100419182754
#
# Table name: roles
#
#  id           :integer(4)      not null, primary key
#  code         :string(255)     not null
#  landing_page :string(255)
#  created_at   :datetime
#  updated_at   :datetime
#

class Role < ActiveRecord::Base
  include BasicModelSecurity
  referenced_by :code

  has_many :users

  def label
    I18n.t("Role.#{code}")
  end

  include Comparable
  def <=>(other)
    label <=> other.label
  end
  
  def report_format
    if code == 'field_coordinator'
      'fc'
    else
      ''
    end    
  end
end


