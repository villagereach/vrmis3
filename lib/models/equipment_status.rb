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
  include BasicModelSecurity

  belongs_to :equipment_type
  belongs_to :stock_room
  belongs_to :health_center_visit
  belongs_to :user
  
  #def self.status_codes
  #  Olmis.configuration['equipment_statuses']
  #end

  #def self.status_options
  #  status_codes.collect{|code| [ I18n.t("EquipmentStatus.#{code}"), code ]}
  #end
  
  #def i18n_status_code
  #  I18n.t("EquipmentStatus.#{status_code}")
  #end
  
  def date
    reported_at.to_date
  end
  
  def date=(d)
    self.reported_at = d.to_date + 12.hours
  end
  
  #def to_label
  #  if value.blank?
  #    "#{ i18n_status_code } #{ I18n.l(reported_at.to_date, :format => :short) }"
  #  else
  #    "#{ i18n_status_code } (#{ value }) #{ I18n.l(reported_at.to_date, :format => :short) }"
  #  end
  #end

  def self.screens
    ['general']
  end
  
  def self.progress_query(date_periods)
    types = EquipmentType.count
    <<-EQUIP
      select health_center_visits.id as id, 
        health_center_visits.visit_month as date_period,
        #{types} as expected_entries,
        count(distinct equipment_statuses.id) as entries,
        'general' as screen
      from health_center_visits 
        left join equipment_statuses on equipment_statuses.health_center_visit_id = health_center_visits.id
        where health_center_visits.visit_month in (#{date_periods})
      group by health_center_visits.id 
    EQUIP
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


