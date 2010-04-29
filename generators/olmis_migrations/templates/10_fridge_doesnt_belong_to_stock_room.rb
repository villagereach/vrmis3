class OlmisFridgeDoesntBelongToStockRoom < ActiveRecord::Migration
  def self.up
    drop_constraint :fridge_statuses, :stock_room_id, :references => :stock_rooms    
    add_column :fridge_statuses, :stock_room_id, :integer, :references => :stock_rooms
    execute 'update fridge_statuses set stock_room_id = (select stock_room_id from fridges where fridges.id = fridge_statuses.fridge_id)'
    change_column_null :fridge_statuses, :stock_room_id, false    
    remove_column :fridges, :stock_room_id
  end

  def self.down
  end
end
