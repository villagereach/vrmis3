class Queries
  class << self
    def connection
      HealthCenterVisit.connection
    end

    RollupIds = <<-SQL
      case
       when visit_month is null                then 't'
       when delivery_zone_id is null           then concat('m:', visit_month)
       when district_id is null                then concat('dz:', delivery_zone_id, ':', visit_month)
       when health_center_id is null           then concat('di:', district_id, ':', delivery_zone_id, ':', visit_month)
       else                                         concat('hc:', health_center_id, ':', district_id, ':', delivery_zone_id, ':', visit_month)
       end as id,

     case
       when visit_month is null                then ''
       when delivery_zone_id is null           then ''
       when district_id is null                then concat('m:', visit_month)
       when health_center_id is null           then concat('dz:', delivery_zone_id, ':', visit_month)
       else                                         concat('di:', district_id, ':', delivery_zone_id, ':', visit_month)
       end as parent_id
    SQL

    RollupSelectIds = <<-SQL
      visit_month,
      provinces.id as province_id,
      delivery_zones.id as delivery_zone_id,
      districts.id as district_id,
      health_centers.id as health_center_id
    SQL

    RollupGroup = "visit_month, delivery_zones.id, districts.id, health_centers.id"

    RegionJoin = <<-SQL
                 administrative_areas districts on districts.id = health_centers.administrative_area_id
      inner join administrative_areas provinces on provinces.id = districts.parent_id
      inner join administrative_areas countries on countries.id = provinces.parent_id
      inner join delivery_zones on delivery_zones.id = health_centers.delivery_zone_id
    SQL

    def rolled_up_target_coverage_by_province_date_period_range(province_id, date_period_range)
      targets = TargetPercentage.all.sort

      date_periods = date_period_range.map { |d| (Date.from_date_period(d) - 1.date_period).to_date_period }

      health_centers = Province.find(province_id).health_centers.map(&:id)

      queries = targets.map { |t| "LEFT JOIN (#{t.tally_subquery(health_centers, date_periods)}) as `#{t.code}` ON `#{t.code}`.health_center_id = health_centers.id AND `#{t.code}`.date_period=months.date_period" }.join("\n")
      values  = targets.map { |t| "sum(`#{t.code}`.value) as `#{t.code}`" }.join(",\n ")
      selects = targets.map { |t| "100.0 * `#{t.code}` / (scaled_population * #{t.percentage / 100.0}) as `#{t.code}`" }.join(", ")
      months  = date_period_range.map { |d| "SELECT '#{(Date.from_date_period(d) - 1.date_period).to_date_period}' AS date_period, '#{d}' AS visit_month" }.uniq.join("\n UNION ALL ")


      connection.select_all(
        HealthCenterVisit.sanitize_sql_for_conditions([<<-SQL, province_id]))
          select #{RollupIds},
            total_periods, scaled_population, population,
            #{selects}
          from (
            select #{RollupSelectIds},
              #{values},
              count(1) as total_periods,
              sum(health_centers.catchment_population / #{ Date.date_periods_per_year }) as scaled_population,
              sum(health_centers.catchment_population) as population
            from (#{months}) as months
              cross join health_centers
              inner join #{RegionJoin}
              #{ queries }
              where provinces.id = ?
              group by #{RollupGroup} with rollup
          ) x
        SQL
    end


    def rolled_up_delivery_intervals_by_province_date_period_range(province_id, date_period_range, acceptable_interval)
      months = delivery_interval_month_subquery(date_period_range)

      connection.select_all(
        HealthCenterVisit.sanitize_sql_for_conditions([<<-SQL, province_id]))
          select #{RollupIds},
            min_current, max_current, min_previous, max_previous, min_interval, max_interval, avg_interval, number_visits, number_acceptable
          from (
          select #{RollupSelectIds},
            min(current_visit_date) as min_current,
            max(current_visit_date) as max_current,
            min(previous_visit_date) as min_previous,
            max(previous_visit_date) as max_previous,
            min(day_interval) as min_interval,
            max(day_interval) as max_interval,
            avg(day_interval) as avg_interval,
            sum(case when current_visit_date is not null then 1 else 0 end) as number_visits,
            sum(case when day_interval <= #{acceptable_interval} then 1 else 0 end) as number_acceptable
            from health_centers
              inner join #{RegionJoin}
              left join (#{months}) months on months.health_center_id = health_centers.id
            where provinces.id = ?
            group by #{RollupGroup} with rollup
          ) x
      SQL
    end


    def rolled_up_visited_health_centers_by_province_date_period_range(province_id, date_period_range)
      months = date_period_range.map { |d| "SELECT '#{d}' AS date_period" }.uniq.join(" UNION ALL ")

      connection.select_all(
        HealthCenterVisit.sanitize_sql_for_conditions([<<-SQL.squish, province_id]))
          select
            #{RollupIds},
            visited_health_centers,
            total_health_centers,
            reported_health_centers
          from (
            select
              #{RollupSelectIds},
              count(distinct health_centers.id) * count(distinct date_period) as total_health_centers,
              count(distinct health_center_visits.id) as reported_health_centers,
              sum(case when health_center_visits.visit_status = 'Visited' then 1 else 0 end) as visited_health_centers
              from (#{months}) as months
              cross join health_centers
              inner join #{RegionJoin}
              left join health_center_visits
                on health_center_visits.visit_month = months.date_period
                and health_center_visits.health_center_id = health_centers.id
              where provinces.id = ?
            group by #{RollupGroup} with rollup) x
      SQL
    end

    def rolled_up_fridge_issues_by_province_date_period_range(province_id, date_period_range)
      connection.select_all(
        HealthCenterVisit.sanitize_sql_for_conditions([<<-SQL.squish, date_period_range.first, date_period_range.last, province_id]))
          select
            #{RollupIds},
            visits,
            total_health_centers,
            problem_count
          from (
            select
              sum(case when health_center_visits.visit_status = 'Visited' then 1 else 0 end) as visits,
              #{RollupSelectIds},
              count(distinct stock_rooms.id) as total_health_centers,
              count(distinct problem_fridge_statuses.stock_room_id) as problem_count
            from health_center_visits
              inner join health_centers on health_centers.id = health_center_id
              inner join #{RegionJoin}
              inner join stock_rooms on stock_rooms.id = stock_room_id
              left join fridge_statuses on fridge_statuses.stock_room_id = stock_rooms.id
              left join (select stock_room_id, reported_at from fridge_statuses
                       inner join fridges problem_fridges
                         on fridge_statuses.fridge_id = problem_fridges.id
                           and fridge_statuses.status_code <> 'OK') problem_fridge_statuses
                     on problem_fridge_statuses.stock_room_id = stock_rooms.id
                     and fridge_statuses.reported_at between #{start_of_date_period_sql('visit_month')} and #{end_of_date_period_sql('visit_month')}
            where visit_month between ? and ?
            and provinces.id = ?
            group by #{RollupGroup} with rollup) x
        SQL
    end

    def rolled_up_stockouts_by_province_date_period_range(products, province_id, date_period_range)
      ids = products.map(&:id).map(&:to_s).join(",")
      return [] if ids.empty?

      connection.select_all(
        HealthCenterVisit.sanitize_sql_for_conditions([<<-SQL.squish, date_period_range.first, date_period_range.last, province_id]))

          select
            #{RollupIds},
            visits,
            #{ products.map { |p|
                 "sum(case when product_id=#{p.id} then stockouts end) as stockouts_#{p.id}"
               }.join(", ")
             }
        from (
          select
            pdt.id as product_id,
            #{RollupSelectIds},
            count(distinct health_center_visit_id) as visits,
            sum(existing_quantity = 0 and expected_delivery_quantity > 0) as stockouts
          from
            (select product_id,
                visit_month,
                health_center_visit_id,
                health_center_id,
                sum(existing_quantity) as existing_quantity,
                sum(expected_delivery_quantity) as expected_delivery_quantity
              from health_center_visit_inventory_groups vig
                inner join health_center_visits v on vig.health_center_visit_id = v.id
                inner join packages pkg on pkg.id = package_id
                where product_id in (#{ids}) and visit_month between ? and ?
              group by product_id, health_center_visit_id, visit_month) x
            inner join health_centers on health_centers.id = health_center_id
            inner join #{RegionJoin}
            inner join products pdt on pdt.id = product_id
            where provinces.id = ?
            group by
              pdt.id,
              #{RollupGroup}
            with rollup
          ) x where product_id is not null group by id, parent_id, visits having id != 't'
      SQL
    end

    def usage_by_area_date_period_range(areas, date_period_range)
      areas = [areas].flatten
      area_ids = areas.map(&:id).map(&:to_s).join(",")

      return [] if area_ids.empty?

      table = areas.first.class.name.tableize
      id_name = table + '.id'
      param_name = areas.first.class.param_name

      services = Product.vaccine.all.sort
      selects = services.map { |s| "sum(case when vaccine_id=#{s.id} then doses_distributed end) as `#{s.id}_distributed`,"+
                                   "sum(case when vaccine_id=#{s.id} then loss end) as `#{s.id}_loss`" }.join(", ")

      pop = param_name == 'health_center_id' ? 'health_centers.catchment_population' : "coalesce(sum(health_centers.catchment_population), #{table}.population)"

      connection.select_all(
        HealthCenterVisit.sanitize_sql_for_conditions([<<-SQL, date_period_range.first, date_period_range.last]))
          select y.population, x.* from (
            select #{id_name} as area_id,
              #{selects}
            from epi_usage_tallies
              inner join health_centers on health_centers.id = health_center_id
              inner join #{RegionJoin}
            where #{id_name} in (#{area_ids})
            and date_period between ? and ?
            group by #{id_name}) x
            inner join
            (select #{id_name} as #{param_name}, #{pop} as population from health_centers inner join #{RegionJoin} group by #{id_name}) y
            on x.area_id = y.#{param_name}
        SQL
    end

    def target_coverage_by_area_date_period_range(areas, date_period_range)
      areas = [areas].flatten
      area_ids = areas.map(&:id).map(&:to_s).join(",")

      return [] if area_ids.empty?

      table = areas.first.class.name.tableize
      id_name = table + '.id'
      param_name = areas.first.class.param_name

      targets = TargetPercentage.all.sort

      date_periods = date_period_range.map { |d| (Date.from_date_period(d) - 1.date_period).to_date_period }

      health_centers = areas.map(&:health_centers).flatten.map(&:id)

        
      queries = targets.map { |t| "LEFT JOIN (#{t.tally_subquery(health_centers, date_periods)}) as `#{t.code}` ON `#{t.code}`.health_center_id = health_centers.id AND `#{t.code}`.date_period=months.date_period" }.join("\n")
      values  = targets.map { |t| "sum(`#{t.code}`.value) as `#{t.code}`" }.join(",\n ")
      selects = targets.map { |t| "`#{t.code}`" }.join(", ")
      months  = date_period_range.map { |d| "SELECT '#{(Date.from_date_period(d) - 1.date_period).to_date_period}' AS date_period, '#{d}' AS visit_month" }.uniq.join("\n UNION ALL ")

      pop = param_name == 'health_center_id' ? 'health_centers.catchment_population' : "coalesce(sum(health_centers.catchment_population), #{table}.population)"

      connection.select_all(
        HealthCenterVisit.sanitize_sql_for_conditions([<<-SQL]))
          select
            x.#{param_name} as area_id,
            #{ date_period_range.to_a.length } * population / #{ Date.date_periods_per_year } as scaled_population,
            population,
            #{selects}
          from (
              select #{id_name} as #{param_name},
              #{values}
            from (#{months}) as months
              cross join health_centers
              inner join #{RegionJoin}
              #{ queries }
            where #{id_name} in (#{area_ids})
            group by #{id_name}) x
            inner join
            (select #{id_name} as #{param_name}, #{pop} as population from health_centers inner join #{RegionJoin} group by #{id_name}) y
            on x.#{param_name} = y.#{param_name}
        SQL
    end

    def stockouts_by_area_date_period_range(products, areas, date_period_range, group_by_month=true)
      ids = products.map(&:id).map(&:to_s).join(",")
      areas = [areas].flatten
      area_ids = areas.map(&:id).map(&:to_s).join(",")
      return [] if area_ids.empty? || ids.empty?
      id_name = areas.first.class.name.tableize + '.id'
      param_name = areas.first.class.param_name

      group_by = group_by_month ? "product_id, visit_month, #{id_name}" : "product_id, #{id_name}"
      RAILS_DEFAULT_LOGGER.debug "STOCKOUTS SUMMARY QUERY"
      connection.select_all(
        HealthCenterVisit.sanitize_sql_for_conditions([<<-SQL.squish, date_period_range.first, date_period_range.last]))
        select
          product_id,
          health_centers.id as health_center_id,
          #{id_name} as #{param_name},
          visit_month as date_period,
          count(distinct health_center_visit_id) as visits,
          sum(case when existing_quantity = 0 and expected_delivery_quantity > 0 then 1 else 0 end) as stockouts,
          sum(case when existing_quantity + delivered_quantity >= expected_delivery_quantity then 1 else 0 end) as full_deliveries
        from
          (select product_id,
              visit_month,
              health_center_visit_id,
              health_center_id,
              sum(existing_quantity) as existing_quantity,
              sum(delivered_quantity) as delivered_quantity,
              sum(expected_delivery_quantity) as expected_delivery_quantity
            from health_center_visit_inventory_groups vig
              inner join health_center_visits v on vig.health_center_visit_id = v.id
              inner join packages pkg on pkg.id = package_id
              where product_id in (#{ids}) and visit_month between ? and ?
            group by product_id, health_center_visit_id, visit_month) x
          inner join health_centers on health_centers.id = health_center_id
          inner join #{RegionJoin}
          inner join products pdt on pdt.id = product_id
        where #{id_name} in (#{area_ids})
        group by #{group_by}
      SQL
    end

    def stockouts_by_product_date_period_range(areas, product, date_period_range)
      ids = areas.map(&:id).map(&:to_s).join(",")
      id_name = areas.first.class.name.tableize + '.id'
      param_name = areas.first.class.param_name
      return [] if ids.empty? or product.nil?

      connection.select_all(
        HealthCenterVisit.sanitize_sql_for_conditions([<<-SQL.squish, date_period_range.first, date_period_range.last, product.id]))
        select
          #{id_name} as id,
          #{id_name} as #{param_name},
          visit_month as date_period,
          count(distinct health_center_visit_id) as visits,
          sum(case when existing_quantity = 0 and expected_delivery_quantity > 0 then 1 else 0 end) as stockouts
        from (select visit_month,
                health_center_id,
                health_center_visit_id,
                sum(existing_quantity) as existing_quantity,
                sum(expected_delivery_quantity) as expected_delivery_quantity
              from health_center_visit_inventory_groups vig
                inner join health_center_visits v on vig.health_center_visit_id = v.id
                inner join packages pkg on pkg.id = package_id
              where visit_month between ? and ?
                and pkg.product_id = ?
              group by health_center_visit_id, visit_month) x
          inner join health_centers on health_centers.id = health_center_id
          inner join #{RegionJoin}
        where #{id_name} in (#{ids})
        group by #{id_name}, visit_month
      SQL
    end

    def end_of_date_period_sql(date_period)
      "LAST_DAY(CONCAT(#{date_period}, '-01'))"
    end

    def start_of_date_period_sql(date_period)
      "CONCAT(#{date_period}, '-01')"
    end

    def health_centers_having_fridge_problems_by_date_period_for_area_date_period_range(area, date_period_range)
      id_name = area.class.name.tableize + '.id'

      connection.select_all(
        HealthCenterVisit.sanitize_sql_for_conditions([<<-SQL.squish, date_period_range.first, date_period_range.last, area.id]))
        select
          #{id_name} as id,
          visit_month as date_period,
          count(distinct stock_rooms.id) as total_health_centers,
          count(distinct problem_fridge_statuses.stock_room_id) as problem_count
          from health_center_visits
          inner join health_centers on health_centers.id = health_center_id
          inner join #{RegionJoin}
          inner join stock_rooms on stock_rooms.id = stock_room_id
          left join fridge_statuses on fridge_statuses.stock_room_id = stock_rooms.id
          left join (select stock_room_id, reported_at from fridge_statuses
                     inner join fridges problem_fridges
                       on fridge_statuses.fridge_id = problem_fridges.id
                         and fridge_statuses.status_code <> 'OK') problem_fridge_statuses
                   on problem_fridge_statuses.stock_room_id = stock_rooms.id
                   and fridge_statuses.reported_at between #{start_of_date_period_sql('visit_month')} and #{end_of_date_period_sql('visit_month')}
        where visit_month between ? and ?
        and #{id_name} = ?
        group by visit_month
      SQL
    end

    def health_centers_visited_for_area_date_period_range(areas, date_period_range, group_by_month = true)
      areas = [areas].flatten
      return if areas.empty?

      id_name = areas.first.class.name.tableize + '.id'
      param_name = group_by_month ? 'date_period' : areas.first.class.param_name
      ids = areas.map(&:id).join(", ")

      months = date_period_range.map { |d| "SELECT '#{d}' AS date_period" }.uniq.join(" UNION ALL ")

      group_by = group_by_month ? "months.date_period" : "#{id_name}"

      connection.select_all(HealthCenterVisit.sanitize_sql_for_conditions([<<-SQL.squish]))
        select
          #{group_by_month ? 'date_period' : id_name} as #{param_name},
          count(distinct health_centers.id) * count(distinct date_period) as total_health_centers,
          count(distinct health_center_visits.id) as reported_health_centers,
          sum(case when health_center_visits.visit_status = 'Visited' then 1 else 0 end) as visited_health_centers
          from (#{months}) as months
          cross join health_centers
          inner join #{RegionJoin}
          left join health_center_visits
            on health_center_visits.visit_month = months.date_period
            and health_center_visits.health_center_id = health_centers.id
          where #{id_name} in (#{ids})
        group by #{group_by}
      SQL
    end

    def stocked_out_health_centers_by_type_area_date_period_range(types, areas, date_period_range)
      return [] if areas.empty? || types.empty?

      area_ids = areas.map(&:id).map(&:to_s).join(",")
      types = types.map { |t| HealthCenterVisit.connection.quote(t) }.join(', ')

      id_name = areas.first.class.name.tableize + '.id'

      connection.select_all(
        HealthCenterVisit.sanitize_sql_for_conditions([<<-SQL.squish, date_period_range.first, date_period_range.last]))
        select
           #{id_name} as id,
           visit_month as date_period,
           product_type as product_type,
           count(distinct health_center_visit_id) as visits,
           sum(any_stockouts) as stockouts
        from (select health_center_visit_id,
                      product_types.code as product_type,
                      case when sum(stocked_out) = 0 then 0 else 1 end as any_stockouts
                from (select health_center_visit_id,
                              product_id,
                              sum(existing_quantity = 0 and expected_delivery_quantity > 0) as stocked_out
                        from health_center_visit_inventory_groups
                              inner join packages on packages.id = package_id
                        where existing_quantity is not null
                        group by health_center_visit_id, product_id) x
                      inner join products on products.id = product_id
                      inner join product_types on product_types.id = product_type_id
                      group by health_center_visit_id, product_type) x
              inner join health_center_visits v on v.id = health_center_visit_id
              inner join health_centers on health_centers.id = health_center_id
              inner join #{RegionJoin}
              where visit_month between ? and ?
              and #{id_name} in (#{area_ids})
              and x.product_type IN (#{types})
            group by #{id_name}, product_type, visit_month
      SQL
    end

    def delivery_interval_month_subquery(date_period_range)
      date_period_range.to_a.uniq.map { |d| <<-MINISQL }.join(" UNION ALL ")
        select health_centers.id as health_center_id,
                '#{d}' as visit_month,
                current.visit_date as current_visit_date,
                previous.visit_date as previous_visit_date,
                datediff(current.visit_date, previous.visit_date) as day_interval
        from health_centers
        left join (select health_center_id, max(visited_at) as visit_date
                       from health_center_visits
                       where visit_status = 'Visited' and visit_month = '#{d}'
                   group by health_center_id) current
          on current.health_center_id = health_centers.id
        left join (select health_center_id, max(visited_at) as visit_date
                       from health_center_visits
                     where visit_status = 'Visited' and visit_month <  '#{d}'
                  group by health_center_id) previous
          on previous.health_center_id = health_centers.id
      MINISQL
    end

    def delivery_interval(regions, date_period_range, acceptable_interval)
      area_ids = regions.map(&:id).map(&:to_s).join(",")
      id_name = regions.first.class.name.tableize + '.id'
      param_name = regions.first.class.param_name
      group = id_name

      months = delivery_interval_month_subquery(date_period_range)

      connection.select_all(
        HealthCenterVisit.sanitize_sql_for_conditions([<<-SQL, date_period_range.first, date_period_range.last]))
      select #{id_name} as #{param_name},
             #{id_name} as id,
             min(current_visit_date) as min_current,
             max(current_visit_date) as max_current,
             min(previous_visit_date) as min_previous,
             max(previous_visit_date) as max_previous,
             min(day_interval) as min_interval,
             max(day_interval) as max_interval,
             avg(day_interval) as avg_interval,
             sum(case when current_visit_date is not null then 1 else 0 end) as number_visits,
             sum(case when day_interval <= #{acceptable_interval} then 1 else 0 end) as number_acceptable
       from health_centers
            inner join #{RegionJoin}
            left join (#{months}) months on months.health_center_id = health_centers.id
        where #{id_name} in (#{area_ids})
     group by #{group}
      SQL
    end
  end
end
