class HealthCenterVisitPeriodicProgress

  def initialize
    @health_center_visits_by_date_period = {}
    @health_center_status_by_date_period = {}
  end
  
  def visits_by_health_center_by_date_period(dps)
    uncached_dps = dps.to_a - @health_center_visits_by_date_period.keys 
    counts = counts_by_health_center_visit_for_date_period(uncached_dps) if uncached_dps.present?
    
    dps.map do |dp|
      [dp, 
        @health_center_visits_by_date_period[dp] ||= begin
          visits = HealthCenterVisit.find_all_by_visit_month(dp, :include => :health_center)
          visits.each do |v| v.entry_counts = counts[v.id][v.date_period] end
    
          Hash[*visits.map { |hcv| [hcv.health_center, hcv] }.flatten]
        end
      ]
    end
  end

  def health_center_visit_for_month(hc, month)
    visits_by_health_center_by_date_period([month]).flatten.last.maybe[hc]
  end
  
  def sanitize_sql(args)
    HealthCenterVisit.send(:sanitize_sql, args)
  end

  def counts_by_health_center_visit_for_date_period(dps)
    tally_hash = Hash[*Olmis.configuration['tallies'].map { |k, v| [k, 0] }.flatten]
    inv_screen_hash = Hash[*Inventory.inventory_screens.map { |s| [s, [0,0]] }.flatten_once]
    counts = Hash.new do |hash, key|      
      hash[key] = Hash[*dps.map { |dp|
        [dp, {
          'cold_chain' => [0, 0],
          'stock_cards' => [0, 0],          
          'equipment' => [0, 0]
        }.merge(tally_hash).
         merge(inv_screen_hash)
      ] }.flatten]
    end
    
    conn = ActiveRecord::Base.connection
    
    dp_sql = dps.map { |dp| sanitize_sql(["?", dp]) }.join(", ")
    
    conn.select_all(fridge_status_count_query(dp_sql)).each do |r| 
      begin
        counts[r['id'].to_i][r['date_period']]['cold_chain'] = [r['fridge_count'].to_i, r['status_count'].to_i]
      rescue
        raise [r, counts[r['id'].to_i]].inspect
      end
    end

    Olmis.configuration['tallies'].each do |tally, definition|
      conn.select_all(tally_count_query(tally.constantize, dp_sql)).each do |r| 
        counts[r['id'].to_i][r['date_period']][tally] = r['count'].to_i 
      end
    end    

    equipment_types = EquipmentType.count
    conn.select_all(equipment_query(dp_sql)).each do |r| 
      counts[r['id'].to_i][r['date_period']]['equipment'] = [equipment_types, r['statuses'].to_i, r['counts'].to_i] 
    end

    stock_cards = StockCard.count
    conn.select_all(stock_card_count_query(dp_sql)).each do |r| 
      counts[r['id'].to_i][r['date_period']]['stock_cards'] = 
        [stock_cards            + r['have'].to_i, 
         r['have_entered'].to_i + r['usage_entered'].to_i] 
    end

    inv_fields = Inventory.possible_fields
    fields_by_screen = Hash[*inv_fields.group_by { |type, package, screen| screen }.map { |screen, fields| [screen, fields.length] }.flatten_once]

    conn.select_all(inventory_query(inv_fields, dp_sql)).each do |r|
      counts[r['id'].to_i][r['date_period']][r['screen']] = [fields_by_screen[r['screen']], r['package_counts'].to_i]
    end
    counts
  end
  
  def status_by_health_center_by_date_periods(dps)
    visits_by_health_center_by_date_period(dps).map do |dp, visits|
      [dp, 
        @health_center_status_by_date_period[dp] ||= 
          Hash.new(HealthCenterVisit::REPORT_NOT_DONE).
            update(
              Hash[*visits.map { |k,v| [k, v.overall_status] }.flatten ])
      ]
    end
  end

  def status_by_health_center_by_date_period(dp)
    status_by_health_center_by_date_periods([dp]).flatten.last
  end
  
  def overall_status_for_date_periods(dps, health_centers)
    status_by_health_center_by_date_periods(dps).map { |dp, statuses|      
      [dp, combine_statuses(statuses.values_at(*health_centers))]
    }
  end
  
  def overall_status_for_date_period(dp, health_centers)
    statuses = overall_status_for_date_periods([dp], health_centers).flatten.last      
  end
  
  def combine_statuses(statuses)
    fs = statuses.first
    if statuses.any? { |s| s != fs }
      HealthCenterVisit::REPORT_INCOMPLETE
    else
      fs
    end
  end

  def health_center_status_by_date_periods(hc, dps)
    status_by_health_center_by_date_periods(dps).map { |dp, statuses| [dp, statuses[hc]] }
  end
  
  def health_center_status(hc, dp)
    status_by_health_center_by_date_period(dp)[hc]
  end
  
  def district_status(dst, dp, hcs = dst.health_centers)
    combine_statuses(status_by_health_center_by_date_period(dp).
        values_at(*hcs))
  end

  alias_method :delivery_zone_status, :district_status 

  def health_center_ids
#    if @health_centers.present?
#      @health_centers.map(&:id).join(", ")
#    else
#      '-1'
#    end
  end
  
  def previous_date_period_sql(dp)
    "date_format((date(concat(#{dp}, '-01')) - interval 1 month), '%Y-%m')"
  end
  
  def tally_count_query(klass, month_ids)
    <<-TALLY
      select health_center_visits.id as id,
        health_center_visits.visit_month as date_period,
        count(distinct #{klass.table_name}.id) as count 
      from health_center_visits 
        left join #{klass.table_name} on 
          #{klass.table_name}.health_center_id = health_center_visits.health_center_id
          and #{klass.table_name}.date_period = #{previous_date_period_sql('health_center_visits.visit_month')}
      where health_center_visits.visit_month in (#{month_ids})
      group by health_center_visits.id 
    TALLY
  end

  def stock_card_count_query(month_ids)
    <<-TALLY
      select health_center_visits.id as id,
        health_center_visits.visit_month as date_period,
        count(stock_card_statuses.have = 1) as have,
        count(stock_card_statuses.have IS NOT NULL) as have_entered,
        count(stock_card_statuses.have = 1 AND stock_card_statuses.used_correctly IS NOT NULL) as usage_entered
      from health_center_visits 
      left join stock_card_statuses on 
        stock_card_statuses.health_center_visit_id = health_center_visits.id
      where health_center_visits.visit_month in (#{month_ids})
      group by health_center_visits.id
    TALLY
  end

  def equipment_query(month_ids)
    <<-EQUIP
      select health_center_visits.id as id, 
        health_center_visits.visit_month as date_period,
        count(distinct equipment_statuses.id) as statuses,
        count(distinct equipment_counts.id) as counts
      from health_center_visits 
        left join equipment_statuses on equipment_statuses.health_center_visit_id = health_center_visits.id
        left join equipment_counts on equipment_counts.health_center_visit_id = health_center_visits.id
        where health_center_visits.visit_month in (#{month_ids})
      group by health_center_visits.id 
    EQUIP
  end

  def inventory_query(inv_fields,month_ids)
    screen_statement = inv_fields.group_by { |type, package, screen| [type, screen] }.map { |locator, fields|
      type, screen = *locator
      "when inventory_type = '#{sanitize_sql(type)}' " +
      "and packages.code in (" +
        fields.map(&:second).map { |p| "'" + sanitize_sql(p.code) + "'" }.join(", ") +
      ") then '#{sanitize_sql(screen)}'"
    }.join("\n      ")
    <<-INV
      select id, date_period, screen, count(distinct pkg_count_id) as package_counts
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
      where health_center_visits.visit_month in (#{month_ids})) x
      where screen != ''
      group by id, screen
    INV
  end
  
  def fridge_status_count_query(month_ids)
    <<-CC
      select health_center_visits.id as id, 
        health_center_visits.visit_month as date_period,
        count(distinct fridges.id) as fridge_count, 
        count(distinct fridge_statuses.id) as status_count
      from health_center_visits 
        left join health_centers on health_centers.id = health_center_id
        left join stock_rooms on stock_rooms.id = health_centers.stock_room_id
        left join fridges on fridges.stock_room_id = stock_rooms.id
        left join fridge_statuses 
          on fridge_statuses.fridge_id = fridges.id
          and date(fridge_statuses.reported_at) = health_center_visits.visited_at
          and fridge_statuses.user_id = health_center_visits.user_id
      where health_center_visits.visit_month in (#{month_ids})
      group by health_center_visits.id 
    CC
  end    
end

