class OlmisIncludePackageCountsInHealthCenterVisitInventoryGroups < ActiveRecord::Migration
  def self.up
    execute <<-SQL
    CREATE VIEW health_center_visit_inventory_groups 
      (id, health_center_visit_id, package_id, existing_quantity, delivered_quantity, expected_delivery_quantity) 
    AS SELECT 
      health_center_visits.id * 100 + ideal_stock_amounts.package_id AS id,
      health_center_visits.id AS health_center_visit_id,
      packages.id,
      existing_package_counts.quantity  * packages.quantity AS existing_quantity,
      delivered_package_counts.quantity * packages.quantity AS delivered_quantity,
      ideal_stock_amounts.quantity      * packages.quantity AS expected_delivery_quantity
    FROM health_center_visits
      INNER JOIN health_centers 
            ON health_centers.id = health_center_id
      CROSS JOIN packages
      INNER JOIN products 
            ON products.id = product_id 
      INNER JOIN product_types 
            ON product_types.id = product_type_id 
      LEFT JOIN ideal_stock_amounts 
            ON ideal_stock_amounts.stock_room_id = health_centers.stock_room_id
            AND ideal_stock_amounts.package_id = packages.id
      LEFT JOIN inventories existing 
            ON existing.stock_room_id = health_centers.stock_room_id 
            AND existing.date = health_center_visits.visited_at 
            AND existing.inventory_type = 'ExistingHealthCenterInventory'
      LEFT JOIN inventories delivered 
            ON delivered.stock_room_id = health_centers.stock_room_id 
            AND delivered.date = health_center_visits.visited_at 
            AND delivered.inventory_type = 'DeliveredHealthCenterInventory'
      LEFT JOIN package_counts existing_package_counts 
            ON existing_package_counts.inventory_id = existing.id 
            AND existing_package_counts.package_id = packages.id
      LEFT JOIN package_counts delivered_package_counts 
            ON delivered_package_counts.inventory_id = delivered.id 
            AND delivered_package_counts.package_id = packages.id
    WHERE product_types.trackable
    SQL
  end

  def self.down
    execute <<-SQL
    CREATE VIEW health_center_visit_inventory_groups 
      (id, health_center_visit_id, package_id, existing_quantity, delivered_quantity, expected_delivery_quantity) 
    AS SELECT 
      health_center_visits.id * 100 + ideal_stock_amounts.package_id AS id,
      health_center_visits.id AS health_center_visit_id,
      packages.id,
      existing_package_counts.quantity  AS existing_quantity,
      delivered_package_counts.quantity AS delivered_quantity,
      ideal_stock_amounts.quantity AS expected_delivery_quantity
    FROM health_center_visits
      INNER JOIN health_centers 
            ON health_centers.id = health_center_id
      CROSS JOIN packages
      INNER JOIN products 
            ON products.id = product_id 
      INNER JOIN product_types 
            ON product_types.id = product_type_id 
      LEFT JOIN ideal_stock_amounts 
            ON ideal_stock_amounts.stock_room_id = health_centers.stock_room_id
            AND ideal_stock_amounts.package_id = packages.id
      LEFT JOIN inventories existing 
            ON existing.stock_room_id = health_centers.stock_room_id 
            AND existing.date = health_center_visits.visited_at 
            AND existing.inventory_type = 'ExistingHealthCenterInventory'
      LEFT JOIN inventories delivered 
            ON delivered.stock_room_id = health_centers.stock_room_id 
            AND delivered.date = health_center_visits.visited_at 
            AND delivered.inventory_type = 'DeliveredHealthCenterInventory'
      LEFT JOIN package_counts existing_package_counts 
            ON existing_package_counts.inventory_id = existing.id 
            AND existing_package_counts.package_id = packages.id
      LEFT JOIN package_counts delivered_package_counts 
            ON delivered_package_counts.inventory_id = delivered.id 
            AND delivered_package_counts.package_id = packages.id
    WHERE product_types.trackable
    SQL
  end
end
