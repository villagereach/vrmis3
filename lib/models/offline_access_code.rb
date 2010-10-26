# == Schema Information
# Schema version: 20100825172820
#
# Table name: warehouses
#
#  id                     :integer(4)      not null, primary key
#  code                   :string(255)     default(""), not null
#  role_id                :integer(4)      not null
#  administrative_area_id :integer(4)
#  created_at             :datetime
#  updated_at             :datetime
#

class OfflineAccessCode < ActiveRecord::Base
  belongs_to :administrative_area
  belongs_to :role

  named_scope :in_area, lambda{|aa|
    administrative_area_id = aa.is_a?(AdministrativeArea) ? aa.id : aa.to_i
    {
      :include => :administrative_area,
      :conditions => { 'administrative_areas.id' => administrative_area_id }
    }
  }

  named_scope :role, lambda{|role|
    role_id = role.is_a?(Role) ? role.id : role.is_a?(String) ? Role.find_by_code(role) : role.to_i
    {
      :include => :role,
      :conditions => { 'roles.id' => role_id }
    }
  }

  include Comparable
  def <=>(other)
    code <=> other.code
  end

end
