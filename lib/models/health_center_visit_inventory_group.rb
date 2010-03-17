# == Schema Information
# Schema version: 20100205183625
#
# Table name: health_center_visit_inventory_groups
#
#  id                         :integer(8)      primary key
#  health_center_visit_id     :integer(4)      default(0), not null
#  package_id                 :integer(4)
#  existing_quantity          :integer(4)
#  delivered_quantity         :integer(4)
#  expected_delivery_quantity :integer(4)      default(0)
#

class HealthCenterVisitInventoryGroup < ActiveRecord::Base
  # This is a view.
  belongs_to :health_center_visit
  belongs_to :package

  report_column :position,           :hidden => true, :sorted_by_default => true do |i| i.package.position end 
  report_column :package_name,       :sql_sort => 'packages.name', :header => 'headers.package_name' do |c| c.package.label end
  report_column :existing_quantity,  :sql_sort => 'existing_quantity', :header => 'headers.existing_quantity', :type => :int
  report_column :delivered_quantity, :sql_sort => 'delivered_quantity', :header => 'headers.delivered_quantity', :type => :int
  report_column :expected_delivery_quantity, :sql_sort => 'expected_delivery_quantity', :header => 'headers.expected_delivery_quantity', :type => :int
end


