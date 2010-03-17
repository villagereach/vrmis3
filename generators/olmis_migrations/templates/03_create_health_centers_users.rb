class CreateHealthCentersUsers < ActiveRecord::Migration
  def self.up
    create_table :health_centers_users, :id => false do |t|
      t.references :health_centers, :null => false
      t.references :users, :null => false
    end
  end

  def self.down
  end
end
