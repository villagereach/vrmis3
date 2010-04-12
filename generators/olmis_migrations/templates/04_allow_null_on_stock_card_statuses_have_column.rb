class OlmisAllowNullOnStockCardStatusesHaveColumn < ActiveRecord::Migration
  def self.up
    change_column :stock_card_statuses, :have, :boolean, :null => true
  end

  def self.down
    change_column :stock_card_statuses, :have, :boolean, :null => false
  end
end
