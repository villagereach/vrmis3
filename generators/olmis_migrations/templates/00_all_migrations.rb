class OlmisAllMigrations < ActiveRecord::Migration
  def self.up
    create_table "roles" do |t|
      t.string   "code",       :null => false
      t.string   "landing_page", :null => true
      t.timestamps
    end

    create_table "users" do |t|
      t.string   "username",                      :null => false
      t.string   "name",          :default => "", :null => false
      t.string   "password_hash", :default => "", :null => false
      t.string   "password_salt", :default => "", :null => false
      t.string   "phone"
      t.datetime "last_login"
      t.references "roles",       :default => 1, :deferrable => true
      t.string   "language", :null => false
      t.string   "timezone", :null => false
      t.boolean  "advanced", :null => false, :default => false
    end

    add_index "users", ["phone"], :name => "index_users_on_phone", :unique => true
    add_index "users", ["username"], :name => "index_users_on_username", :unique => true

    create_table "administrative_areas" do |t|
      t.string   "code",       :null => false
      t.integer  "population"
      t.integer  "parent_id",  :references => :administrative_areas, :deferrable => true
      t.string   "type",       :null => false
      t.text     "polygon"
      t.timestamps
    end

    add_index "administrative_areas", ["code"], :name => "index_locations_on_code", :unique => true
#    add_index "administrative_areas", ["parent_id"], :name => "locations_parent_id_fkey"

    create_table "administrative_areas_users", :id => false do |t|
      t.references "users",                :null => false, :cascade => true, :deferrable => true
      t.references "administrative_areas", :null => false, :cascade => true, :deferrable => true
    end

#    add_index "administrative_areas_users", ["administrative_area_id"], :name => "administrative_areas_users_administrative_area_id_fkey"
#    add_index "administrative_areas_users", ["user_id"], :name => "administrative_areas_users_user_id_fkey"
#
    create_table "stock_rooms" do |t|
      t.timestamps
    end

    create_table "warehouses" do |t|
      t.string "code"
      t.references :administrative_areas, :null => false, :deferrable => true
      t.references :stock_rooms,          :null => false, :deferrable => true
      t.timestamps
    end

    add_index "warehouses", ["code"], :unique => true
    
    create_table "delivery_zones" do |t|
      t.string   "code"
      t.references "warehouses", :null => false
      t.timestamps
    end

    add_index "delivery_zones", ["code"], :name => "index_delivery_zones_on_code", :unique => true

    create_table "delivery_zones_users", :id => false do |t|
      t.references :users, :null => false
      t.references :delivery_zones, :null => false
    end
    
    create_table :health_centers do |t|
      t.string :code,        :null => false, :default => ''
      t.text   :description, :null => false, :default => ''
      t.references :stock_rooms, :null => false, :deferrable => true
      t.references :delivery_zones,       :null => false, :deferrable => true
      t.references :administrative_areas, :null => false, :deferrable => true
      t.timestamps
    end

    add_index "health_centers", ["code"], :name => "index_health_centers_on_code", :unique => true

    create_table "health_center_visits" do |t|
      t.references "users",                                       :null => false, :deferrable => true
      t.references "health_centers",                              :null => false, :deferrable => true
      t.string   "visit_month",                                   :null => false
      t.date     "visited_at",                                    :null => false
      t.string   "vehicle_code",           :default => "",        :null => false
      t.string   "visit_status",           :default => "Visited", :null => false
      t.text     "notes",                                         :null => false
      t.string   "data_status",            :default => "pending", :null => false
      t.boolean  "epi_data_ready",         :default => true,      :null => false
      t.timestamps
    end

 #   add_index "health_center_visits", ["health_center_id"], :name => "health_center_visits_health_center_id_fkey"
 #   add_index "health_center_visits", ["user_id"], :name => "health_center_visits_user_id_fkey"
    add_index "health_center_visits", ["health_center_id", "visit_month"], :unique => true

    create_table "data_sources" do |t|
      t.string   "type",       :null => false
      t.timestamps
    end

    create_table "data_submissions" do |t|
      t.references :data_sources, :null => false
      t.references :users, :null => false
      t.date    :created_on
      t.integer :created_by, :references => :users
      t.string  :content_type
      t.string  :character_set
      t.string  :remote_ip
      t.string  :filename
      t.string  :status
      t.string  :message
      t.text    :data
      t.timestamps
    end

    create_table "data_submissions_health_center_visits", :id => false do |t|
      t.references :health_center_visits, :name => 'dt_sbmssns_hlth_cntr_vsts_hlth_cntr_vst_id_fkey'
      t.references :data_submissions, :name => 'dt_sbmssns_hlth_cntr_vsts_dt_sbmssn_id_fkey'
    end

    create_table "descriptive_categories" do |t|
      t.string   "code",        :null => false
      t.timestamps
    end

    add_index "descriptive_categories", ["code"], :name => "index_descriptive_categories_on_code", :unique => true

    create_table "descriptive_values" do |t|
      t.references "descriptive_categories",                :null => false, :deferrable => true
      t.string   "code",                                    :null => false
      t.integer  "position",                :default => 0, :null => false
      t.timestamps
    end

#    add_index "descriptive_values", ["descriptive_category_id"], :name => "descriptive_values_descriptive_category_id_fkey"
    add_index "descriptive_values", ["code", "descriptive_category_id"], :name => "index_descriptive_values_on_code_and_descriptive_category_id", :unique => true


    create_table "target_percentages" do |t|
      t.string   "code",                                                            :null => false
      t.decimal  "percentage",       :precision => 4, :scale => 2, :default => 0.0, :null => false
      t.string   "stat_tally_klass",                                                :null => false
      t.timestamps
    end

    add_index "target_percentages", "code", :unique => true

    create_table "descriptive_values_target_percentages", :id => false do |t|
      t.references "descriptive_values", :null => false, :cascade => true, :deferrable => true
      t.references "target_percentages", :null => false, :cascade => true, :deferrable => true
    end

#    add_index "descriptive_values_target_percentages", ["descriptive_value_id"], :name => "descriptive_values_target_percentages_descriptive_value_id_fkey"
#    add_index "descriptive_values_target_percentages", ["target_percentage_id"], :name => "descriptive_values_target_percentages_target_percentage_id_fkey"
#
    create_table "product_types" do |t|
      t.string  "code", :null => false
      t.integer "position", :default => 0, :null => false
      t.boolean "trackable", :default => false
    end

    add_index "product_types", "code", :unique => true

    create_table "products" do |t|
      t.string   "code",                      :null => false
      t.references "product_types",           :null => false
      t.integer  "position",   :default => 0, :null => false
      t.timestamps
    end

    add_index "products", "code", :unique => true

    create_table "packages" do |t|
      t.string   "code",        :default => '', :null => false
      t.integer  "quantity",   :default => 0
      t.references "products",                 :null => false, :cascade => true, :deferrable => true
      t.integer  "position",   :default => 0,  :null => false
      t.timestamps
    end

    add_index "packages", ["code"], :unique => true

    create_table "equipment_types" do |t|
      t.string   "code",                      :null => false
      t.integer  "position",   :default => 0, :null => false
      t.timestamps
    end

    add_index "equipment_types", "code", :unique => true
    
    create_table "equipment_counts" do |t|
      t.references "equipment_types",      :null => false, :deferrable => true
      t.references "stock_rooms",          :null => false, :cascade => true, :deferrable => true
      t.references "health_center_visits", :null => false, :deferrable => true
      t.integer  "quantity"
      t.timestamps
    end

#    add_index "equipment_counts", ["equipment_type_id"], :name => "equipment_counts_equipment_type_id_fkey"
#    add_index "equipment_counts", ["health_center_visit_id"], :name => "equipment_counts_health_center_visit_id_fkey"
#    add_index "equipment_counts", ["stock_room_id"], :name => "equipment_counts_stock_room_id_fkey"

    create_table "equipment_statuses" do |t|
      t.references "equipment_types",      :null => false, :deferrable => true
      t.references "stock_rooms",          :null => false, :cascade => true, :deferrable => true
      t.references "health_center_visits", :null => false, :deferrable => true
      t.string     "status_code",          :null => false
      t.datetime   "reported_at",          :null => false
      t.text       "notes"
      t.timestamps
    end

#    add_index "equipment_statuses", ["equipment_type_id"], :name => "equipment_statuses_equipment_type_id_fkey"
#    add_index "equipment_statuses", ["health_center_visit_id"], :name => "equipment_statuses_health_center_visit_id_fkey"
#    add_index "equipment_statuses", ["stock_room_id"], :name => "equipment_statuses_stock_room_id_fkey"
#
    create_table "fridge_models" do |t|
      t.decimal  "capacity",     :precision => 10, :scale => 2, :null => false, :default => 0.0
      t.string   "code",         :null => false
      t.text     "description",  :null => false, :default => ''
      t.string   "power_source", :null => false, :default => ''
      t.timestamps
    end

    add_index "fridge_models", ["code"], :unique => true

    create_table "fridges" do |t|
      t.string   "code"
      t.text     "description"
      t.references "fridge_models", :null => false, :deferrable => true
      t.references "stock_rooms",   :null => false, :cascade => true, :deferrable => true
      t.timestamps
    end

    add_index "fridges", ["code"], :unique => true
                                              
 #   add_index "fridges", ["fridge_model_id"], :name => "fridges_fridge_model_id_fkey"
 #   add_index "fridges", ["stock_room_id"], :name => "fridges_stock_room_id_fkey"
 #
    create_table "fridge_statuses" do |t|
      t.references "fridges",   :null => false, :cascade => true, :deferrable => true
      t.references "users", :deferrable => true
      t.string   "status_code", :null => false, :default => ''
      t.integer  "temperature"
      t.datetime "reported_at",        :null => false
      t.text     "notes"
      t.timestamps
    end

#    add_index "fridge_statuses", ["fridge_id"], :name => "fridge_statuses_fridge_id_fkey"
#    add_index "fridge_statuses", ["user_id"], :name => "fridge_statuses_user_id_fkey"
    add_index :fridge_statuses, [:fridge_id, :reported_at, :status_code], :name => 'idx_fridge_statuses_on_fridge_and_time_and_status'

    create_table "inventories" do |t|
      t.references "stock_rooms", :null => false, :cascade => true, :deferrable => true
      t.date     "date",          :null => false
      t.string   "inventory_type",:null => false
      t.references "users",       :null => false, :deferrable => true
      t.timestamps
    end

#    add_index "inventories", ["stock_room_id"], :name => "inventories_stock_room_id_fkey"
#    add_index "inventories", ["user_id"], :name => "inventories_user_id_fkey"

    create_table "package_counts" do |t|
      t.references "inventories", :null => false, :cascade => true, :deferrable => true
      t.references "packages",   :null => false, :deferrable => true
      t.integer  "quantity",     :null => true
      t.timestamps
    end

#    add_index "package_counts", ["inventory_id"], :name => "package_counts_inventory_id_fkey"
#    add_index "package_counts", ["package_id"], :name => "package_counts_package_id_fkey"

    create_table "ideal_stock_amounts" do |t|
      t.references "stock_rooms",                :null => false, :cascade => true, :deferrable => true
      t.references "packages",                   :null => false, :deferrable => true
      t.integer  "quantity",      :default => 0, :null => false
      t.timestamps
    end

#    add_index "ideal_stock_amounts", ["package_id"], :name => "ideal_stock_amounts_package_id_fkey"
#    add_index "ideal_stock_amounts", ["stock_room_id", "package_id"], :name => "index_ideal_stock_amounts_on_stock_room_id_and_package_id", :unique => true

    create_table :stock_cards do |t|
      t.string :code, :null => false
      t.integer :position, :null => false

      t.timestamps
    end

    add_index :stock_cards, :code, :unique => true

    create_table :stock_card_statuses do |t|
      t.references :stock_cards, :null => false
      t.references :stock_rooms, :null => false
      t.references :health_center_visits, :null => false
      t.boolean :have,           :null => false
      t.boolean :used_correctly, :null => true
      t.date    :reported_at,    :null => true
      t.timestamps
    end

    create_table "sessions" do |t|
      t.string   "session_id", :null => false
      t.text     "data"
      t.timestamps
    end

    add_index "sessions", ["session_id"], :name => "index_sessions_on_session_id"
    add_index "sessions", ["updated_at"], :name => "index_sessions_on_updated_at"

    create_table :street_addresses do |t|
      t.string :phone,    :null => false, :default => ''
      t.string :name,     :null => false, :default => ''
      t.string :address1, :null => false, :default => ''
      t.string :address2, :null => false, :default => ''
      t.string :city,     :null => false, :default => ''
      t.string :postal_code, :null => false, :default => ''
      t.text   :notes,    :null => false, :default => ''
      t.float  :latitude
      t.float  :longitude
      t.integer :addressed_id
      t.string  :addressed_type
      t.timestamps
    end
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
