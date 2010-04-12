class OlmisAddOtherNonVisitReasonToHealthCenterVisit < ActiveRecord::Migration
  def self.up
    add_column :health_center_visits, :other_non_visit_reason, :string
  end

  def self.down
    remove_column :health_center_visits, :other_non_visit_reason
  end
end
