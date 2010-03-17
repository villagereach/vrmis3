# == Schema Information
# Schema version: 20100127014005
#
# Table name: equipment_statuses
#
#  id                     :integer(4)      not null, primary key
#  equipment_type_id      :integer(4)      not null
#  stock_room_id          :integer(4)      not null
#  health_center_visit_id :integer(4)      not null
#  status_code            :string(255)     not null
#  reported_at            :datetime        not null
#  notes                  :text
#  created_at             :datetime
#  updated_at             :datetime
#

class EquipmentStatus < ActiveRecord::Base 
  unloadable

  include BasicModelSecurity

  belongs_to :equipment_type
  belongs_to :stock_room
  belongs_to :health_center_visit
  belongs_to :user
  
  validates_presence_of :equipment_type_id, :stock_room_id, :status_code
  validates_presence_of :stock_room_id
  validates_presence_of :health_center_visit_id

  def self.status_codes
    EQUIPMENT_STATUS_KEYS
  end

  def self.status_options
    status_codes.collect{|code| [ I18n.t("EquipmentStatus.#{code}"), code ]}
  end
  
  def i18n_status_code
    I18n.t("EquipmentStatus.#{status_code}")
  end
  
  def date
    reported_at.to_date
  end
  
  def date=(d)
    self.reported_at = d.to_date + 12.hours
  end
  
  def to_label
    if value.blank?
      "#{ i18n_status_code } #{ I18n.l(reported_at.to_date, :format => :short) }"
    else
      "#{ i18n_status_code } (#{ value }) #{ I18n.l(reported_at.to_date, :format => :short) }"
    end
  end

  #def damage_alert_level
  #  case status_code
  #  when 'Working'    then 0
  #  when 'Inoperable' then 2
  #  when 'Damaged'    then 1
  #  else 0
  #  end
  #end

  #def operating_status?
  #  status.operating_status?
  #end

  #def urgent?
  #  status.urgent?
  #end

end


