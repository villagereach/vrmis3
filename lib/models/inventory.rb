# == Schema Information
# Schema version: 20100205183625
#
# Table name: inventories
#
#  id             :integer(4)      not null, primary key
#  stock_room_id  :integer(4)      not null
#  date           :date            not null
#  inventory_type :string(255)     not null
#  user_id        :integer(4)      not null
#  created_at     :datetime
#  updated_at     :datetime
#

class Inventory < ActiveRecord::Base
  belongs_to :stock_room
  belongs_to :user
  
  has_many :package_counts

  validates_presence_of :stock_room_id
  validates_presence_of :user_id
  validates_presence_of :date
  validates_presence_of :inventory_type
  validates_uniqueness_of :date, :scope=>[:stock_room_id, :inventory_type]
  validates_associated :package_counts

  def self.types
    %w(ExistingHealthCenterInventory DeliveredHealthCenterInventory SpoiledHealthCenterInventory)
  end

  def self.directly_collected_types
    %w(ExistingHealthCenterInventory DeliveredHealthCenterInventory SpoiledHealthCenterInventory)
  end
  
  def self.screens
    %w(epi_inventory)
  end
  
  def self.nullable_types
    types - ['DeliveredHealthCenterInventory']
  end

  def self.possible_fields()
    returning Set.new do |fields|
      HealthCenterVisit.screens.each do |screen|
        types.each do |t|
          Package.all.each do |package|
            fields << [t, package, screen] if package.inventoried_by_type?(t, screen)
          end
        end
      end
    end
  end

  def package_count_quantity_by_package
    Hash[*package_counts_by_package.map { |pkg, count| [pkg, count.quantity] }.flatten]
  end

  def package_counts_by_package_code
    Hash[*package_counts_by_package.map { |pkg, count| [pkg.code, count] }.flatten]
  end
  
  protected

  def package_counts_by_package(package_options={})
    pc_hash = Hash[*package_counts.map { |pc| [pc.package, pc] }.flatten]
    
    Package.all(package_options).select { |p| Inventory.screens.any? { |s| p.inventoried_by_type?(self, s) } }.each do |p|
      pc_hash[p] ||= package_counts.build(:package => p, :quantity => nil)
      pc_hash[p].inventory = self
    end
    
    pc_hash
  end

  def self.process_data_submission(visit, params)
    errors = {}
    
    inventories = visit.find_or_create_inventory_records
    stock = visit.ideal_stock

    params[:inventory].each do |key, value|
      (stock.keys - [:ideal]).each do |type|
        if (record = stock[type][key]) && value.has_key?(type)
          if value[type].blank? && value["#{type}/NR"].to_i == 0
            # No quantity value is specified and NR is not checked
            record.delete unless record.new_record?
          else
            # A quantity value is specified or NR is checked
            record.quantity = (value.has_key?("#{type}/NR") && value["#{type}/NR"].to_i == 1) ? nil : value[type]
            record.save
            unless record.errors.empty?
              errors[key + '_' + type] = record.errors
            end
          end
        end
      end
    end

    # Remove any blank package counts
    inventories.each { |i|
      i.package_counts.delete_if{|pc| pc.id.nil?}
      i.save
    }
    
    errors
  end    
  
  def self.progress_query(date_periods)
    inv_fields = possible_fields.select { |type, package, screen| screens.include?(screen) }

    screen_statement = inv_fields.group_by { |type, package, screen| [type, screen] }.map { |locator, fields|
      type, screen = *locator
      "when inventory_type = '#{sanitize_sql(type)}' " +
      "and packages.code in (" +
        fields.map(&:second).map { |p| "'" + sanitize_sql(p.code) + "'" }.join(", ") +
      ") then '#{sanitize_sql(screen)}'"
    }.join("\n      ")

    expectation_statement = inv_fields.group_by { |type, package, screen| screen }.map { |screen, fields|
      "when screen = '#{sanitize_sql(screen)}' then #{fields.length}"
    }.join("\n      ")
    
    <<-INV
    select 
      id, 
      date_period, 
      screen,
      case #{expectation_statement} else 0 end as expected_entries,
      count(distinct pkg_count_id) as entries
      from (
        select
          health_center_visits.id as id, 
          health_center_visits.visit_month as date_period,
          package_counts.id as pkg_count_id,
          case #{screen_statement} else '' end as screen
      from health_center_visits
        left join health_centers on health_centers.id = health_center_id
        left join stock_rooms on stock_rooms.id = health_centers.stock_room_id
        left join inventories
          on inventories.stock_room_id = stock_rooms.id
          and inventories.date = health_center_visits.visited_at
        left join package_counts on package_counts.inventory_id = inventories.id
        left join packages       on packages.id = package_counts.package_id
      where health_center_visits.visit_month in (#{date_periods})) x
      where screen != ''
      group by id, screen
    INV
  end
end


