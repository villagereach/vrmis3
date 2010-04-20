class OlmisRedefineEquipmentStatus < ActiveRecord::Migration
  def self.up
    add_column :health_center_visits, :equipment_notes, :text

    add_column :equipment_statuses, :present, :boolean
    add_column :equipment_statuses, :working, :boolean
    remove_column :equipment_statuses, :status_code
    remove_column :equipment_statuses, :notes

    drop_table :equipment_counts
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
