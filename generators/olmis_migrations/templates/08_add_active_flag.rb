class OlmisAddActiveFlag < ActiveRecord::Migration
  TABLES = %w(equipment_types packages descriptive_values stock_cards products product_types)

  def self.up
    TABLES.each do |table|
      add_column table, :active, :boolean, :null => false, :default => true
    end
  end

  def self.down
    TABLES.each do |table|
      remove_column table, :active
    end
  end
end
