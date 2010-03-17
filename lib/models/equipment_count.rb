# == Schema Information
# Schema version: 20100127014005
#
# Table name: equipment_counts
#
#  id                     :integer(4)      not null, primary key
#  equipment_type_id      :integer(4)      not null
#  stock_room_id          :integer(4)      not null
#  health_center_visit_id :integer(4)      not null
#  quantity               :integer(4)
#  created_at             :datetime
#  updated_at             :datetime
#

class EquipmentCount < ActiveRecord::Base
  include BasicModelSecurity

  belongs_to :equipment_type
  belongs_to :stock_room
  belongs_to :health_center_visit

  validates_numericality_of :quantity, :only_integer => true, :greater_than_or_equal_to => 0, :allow_nil => true
  validates_presence_of :stock_room_id
  validates_presence_of :health_center_visit_id
  
  def nr
    !new_record? && quantity.nil?
  end
  
  def corresponding_status
    health_center_visit.equipment_statuses.detect { |s| s.equipment_type_id == equipment_type_id }
  end
  
  report_column :position, :hidden => true, :sorted_by_default => true, :type => :int do |c| c.equipment_type.position end
  report_column :type,     :header => 'headers.type'  do |c| c.equipment_type.label end
  report_column :quantity, :header => 'headers.quantity', :type => :int
  report_column :status,   :header => 'headers.status' do |c| c.corresponding_status.maybe.i18n_status_code end
end



