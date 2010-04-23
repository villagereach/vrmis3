class ActiveFridgeModels < ActiveRecord::Migration
  def self.up
    add_column :fridge_models, :active, :boolean, :null => false, :default => true    
    add_column :fridge_models, :position, :integer, :null => false, :default => 0    
  end

  def self.down
    remove_column :fridge_models, :active, :position
  end
end
