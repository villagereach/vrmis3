class AddOfflineAccessCodes < ActiveRecord::Migration
  def self.up
    create_table :offline_access_codes do |t|
      t.string :code, :null => false
      t.references :roles, :null => false
      t.references :administrative_areas
      t.timestamps
    end
  end

  def self.down
    drop_table :offline_access_codes
  end
end
