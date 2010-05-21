class OlmisFridgeDoesntBelongToStockRoom < ActiveRecord::Migration
  def self.up
    add_column :fridge_statuses, :stock_room_id, :integer, :references => :stock_rooms
    execute 'update fridge_statuses set stock_room_id = (select stock_room_id from fridges where fridges.id = fridge_statuses.fridge_id)'
    change_column_null :fridge_statuses, :stock_room_id, false    
    # the execute could be replaced by drop_constraint but the current drop_constraint is buggy. if drop_constraint works, it can be something like the following
    #drop_constraint :fridges, {:name => :fridges_stock_room_id_fkey, :foreign_key => true} 
    execute "ALTER TABLE fridges DROP FOREIGN KEY fridges_stock_room_id_fkey"
    remove_column :fridges, :stock_room_id
  end

  def self.down
  end
end
