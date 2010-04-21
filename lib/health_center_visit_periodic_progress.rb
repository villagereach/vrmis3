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
          visits.each do |v| v.entry_counts = counts[v.id] end
    
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
  
  def counts_by_health_center_visit_for_date_period(dps, ids=[])
    tables = HealthCenterVisit.tables

    dp_sql = dps.map { |dp| sanitize_sql(["?", dp]) }.join(", ")

    if ids.present?
      ids = ids.map { |i| sanitize_sql(i) }.join(", ")
    end

    counts = Hash.new do |hash, key|      
      hash[key] = { }
    end
    
    conn = ActiveRecord::Base.connection
    
    tables.each do |table|
      query = table.progress_query(dp_sql)

      if ids.present?
        query = "select * from (#{query}) x where id in (#{ ids })"
      end
      
      conn.select_all(query).each do |r|
        counts[r['id'].to_i][r['screen']] = [r['expected_entries'].to_i, r['entries'].to_i]
      end
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
end

