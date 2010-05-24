class AddWarehouseVisits < ActiveRecord::Migration
  def self.up
    create_table :warehouse_visits do |t|
      t.references :warehouses, :null => false
      t.string  :visit_month,   :null => false
      t.integer :request_id,    :null => false, :references => :inventories
      t.integer :pickup_id,     :null => false, :references => :inventories
      t.timestamps
    end

    create_table :data_submissions_warehouse_visits, :id => false do |t|
      t.references :data_submissions, :null => false
      t.references :warehouse_visits, :null => false
    end
  end

  def self.down
    drop_table :data_submissions_warehouse_visits
    drop_table :warehouse_visits
  end
end
