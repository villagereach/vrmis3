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

  acts_as_visit_model

  belongs_to :equipment_type
  belongs_to :stock_room
  belongs_to :health_center_visit
  belongs_to :user

  def date
    reported_at.to_date
  end
  
  def date=(d)
    self.reported_at = d.to_date + 12.hours
  end

  def self.xforms_to_params(xml)
    Hash[
      *xml.xpath('/olmis/equipment_status/item').map do |equip|
        [
          equip['for'].to_s,
          {
            'present' => equip['present'].to_s,
            'working' => equip['working'].to_s
          }
        ]
      end.flatten_once
    ]
  end

  def self.visit_navigation_category
    'equipment'
  end

  def self.odk_to_params(xml)
    Hash[
      *xml.xpath('/olmis/hcvisit/visit/equipment_status/*').find_all{|n| n.name.starts_with?('item_')}.map do |equip|
        [
          equip.name[5..-1],
          {
            'present' => equip.xpath('./present').text,
            'working' => equip.xpath('./working').text
          }
        ]
      end.flatten_once
    ]
  end
  
  def self.process_data_submission(visit, params)
    errors = {}
    
    equipment_statuses = visit.find_or_initialize_equipment_statuses

    equipment_notes = params[:equipment_status].delete(:notes)
    visit.update_attributes(:equipment_notes => equipment_notes) unless equipment_notes.blank?

    params[:equipment_status].each do |key, values|
      record = equipment_statuses.detect{|es| es.equipment_type_code == key }

      # Skip if no data entered for a new item
      next if record.new_record? && values["present"].blank? && values["working"].blank?

      db_values = values.inject({}){|hash,(key,value)| hash[key] = value == "true" || (value == "false" ? false : nil) ; hash }

      record.date = visit.date
      record.update_attributes(db_values)
      unless record.errors.empty?
        errors[key] = record.errors
      end
    end
    
    errors
  end
  
  def self.progress_query(date_periods)
    types = EquipmentType.count
    <<-EQUIP
      select health_center_visits.id as id, 
        health_center_visits.visit_month as date_period,
        #{types} as expected_entries,
        count(distinct equipment_statuses.id) as entries,
        'equipment_status' as screen
      from health_center_visits 
        left join equipment_statuses on equipment_statuses.health_center_visit_id = health_center_visits.id
        where health_center_visits.visit_month in (#{date_periods})
      group by health_center_visits.id 
    EQUIP
  end  
end


