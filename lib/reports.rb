# -*- coding: utf-8 -*-
class Reports
  class << self
    def rolled_up_delivery_intervals_by_province_date_period_range(province_id, date_period_range, acceptable_interval)
      rollup_series, data = rollup_data(Queries.rolled_up_delivery_intervals_by_province_date_period_range(province_id, date_period_range, acceptable_interval))

      visits = data['number_visits'].map(&:to_i)
      data['visit_ratio'] = data['number_acceptable'].map(&:to_i).zip(visits)
      data['interval'] = visits.zip(data['min_interval'], data['max_interval']).map { |v, min, max| if v == 0 then nil elsif v == 1 then min.to_i else [min.to_i, max.to_i] end }

      previous_month_span, current_month_span = ['previous', 'current'].map { |t| delivery_spans(data["min_#{t}"].zip(data["max_#{t}"])) }

      rollup_series +
        [
          [ I18n.t('reports.series.delivery_interval.previous_month_dates'), previous_month_span,  { :data_type => :text  } ],
          [ I18n.t('reports.series.delivery_interval.current_month_dates'),  current_month_span,    { :data_type => :text  } ],
          [ I18n.t('reports.series.delivery_interval.days_between'),         data['interval'],     { :data_type => :interval } ],
          [ I18n.t('reports.series.delivery_interval.number_acceptable', :num => acceptable_interval),    data['visit_ratio'],  { :data_type => :ratio } ],
        ]
    end

    def rolled_up_target_coverage_by_province_date_period_range(province_id, date_period_range)
      rollup_series, data = rollup_data(Queries.rolled_up_target_coverage_by_province_date_period_range(province_id, date_period_range))
      rollup_series + [[I18n.t('reports.population'), data['population'], { :data_type => :int }]] +
        TargetPercentage.all.sort.map { |t|
          [t.label, data[t.code], { :data_type => :pct, :precision => 0 }]
        }
    end

    def rolled_up_visited_health_centers_by_province_date_period_range(province_id, date_period_range)
      rollup_series, data = rollup_data(Queries.rolled_up_visited_health_centers_by_province_date_period_range(province_id, date_period_range))

      visits           = (data.delete('visited_health_centers') || []).map(&:to_i)
      total            = (data.delete('total_health_centers') || []).map(&:to_i)
      reported         = (data.delete('reported_health_centers') || []).map(&:to_i)

      vtr_triples = visits.zip(total, reported)

      visit_percentage = vtr_triples.map { |v, t, r| 100.0 * v / t }
      not_visited      = vtr_triples.map { |v, t, r| t - v }
      not_reported     = vtr_triples.map { |v, t, r| t - r }

       rollup_series +
        [
          [ I18n.t('reports.series.total'),        total,            { :data_type => :int }],
          [ I18n.t('reports.series.visited'),      visit_percentage, { :data_type => :pct }],
          [ I18n.t('reports.series.not_visited'),  not_visited,      { :data_type => :int }],
          [ I18n.t('reports.series.not_reported'), not_reported,     { :data_type => :int }],
        ]
    end

    def rolled_up_fridge_issues_by_province_date_period_range(province_id, date_period_range)
      rollup_series, data = rollup_data(Queries.rolled_up_fridge_issues_by_province_date_period_range(province_id, date_period_range))

      visits = data.delete('visits') || []
      hcs =    (data.delete('total_health_centers') || []).map(&:to_f)
      probs =  data.delete('problem_count') || []

      rollup_series +
        [
          [ I18n.t('reports.series.total_visits'), visits, { :data_type => :int }],
          [ I18n.t('reports.series.fridges.broken_or_missing'), probs.map_with_index { |d, i| 100.0 * d.to_f / hcs[i] },
            { :data_type => :format, :method => hc_format_method(:zero?.to_proc, nil, nil, 'stockout', :pct) } ]
        ]
    end

    def rolled_up_stockouts_by_province_date_period_range(province_id, date_period_range)
      rollup_series, data = rollup_data(Queries.rolled_up_stockouts_by_province_date_period_range(Product.trackable.all, province_id, date_period_range))

      visits = data.delete('visits') || []

      stockouts = data.map { |k, v|
        type, id = k.split('_')
        raise "Unknown product: #{k}" unless id && type == 'stockouts'
        product = Product.find(id)
        [
          product, v.map(&:to_i), { :data_type => :format, :column_group => product.type_label,
                                    :method => hc_format_method(:zero?.to_proc, I18n.t('OK'), I18n.t('OUT'),'stockout', :int) }
        ]
      }

      rollup_series +
        [ [I18n.t('reports.series.total_visits'), visits, { :data_type => :int }] ] +
        stockouts.sort_by(&:first).map { |p, d, o| [p.label_without_type, d, o] }
    end

    def target_coverage_by_area_date_period_range(regions, date_period_range)
      regions_by_id = Hash[*regions.map { |r| [r.id.to_s, r] }.flatten]
      
      data = Queries.target_coverage_by_area_date_period_range(regions, date_period_range).
        sort_by { |r| r['region'] = regions_by_id[r['area_id']] }.
        transpose_hashes
      
      series = 
        [
          [ I18n.t('reports.axes.'+regions.first.class.name.tableize.singularize), data['region'].map(&:label), { :data_type => :text, :th => true }],
          [ I18n.t('reports.series.population'), data['population'], { :data_type => :int }],
        ]
        
      TargetPercentage.all.sort.each do |target|
        target_size = data['scaled_population'].map { |s| s.nil? ? nil : s.to_i * target.percentage / 100.0 }
        #PSQL-specific help, sanitize target.code to the alias in SQL query. 
        # see similar logic in queries.rb#target_coverage_by_area_date_period_range
        coverage = target_size.zip(data[target.code.gsub('-', '_')]).map { |z, n| z.nil?  || z.zero? ? nil : 100 * n.to_f / z.to_i } 
        series << [ I18n.t('reports.series.target_group_size'),   target_size,      { :column_group => target.label, :data_type => :int }]
        series << [ I18n.t('reports.series.target_vaccinations'), data[target.code],{ :column_group => target.label, :data_type => :int }]
        series << [ I18n.t('reports.series.target_coverage'),     coverage,         { :column_group => target.label, :data_type => :pct }]
      end

      series
    end

    
    def usage_by_area_date_period_range(regions, date_period_range)
      regions_by_id = Hash[*regions.map { |r| [r.id.to_s, r] }.flatten]
      
      data = Queries.usage_by_area_date_period_range(regions, date_period_range).
        sort_by { |r| r['region'] = regions_by_id[r['area_id']] }
      
      if data.empty?
        [ [ I18n.t('reports.axes.'+regions.first.class.name.tableize.singularize), regions.map(&:label), { :data_type => :text }], ]
      else 
        data = data.transpose_hashes

        series = 
          [
            [ I18n.t('reports.axes.'+regions.first.class.name.tableize.singularize), data['region'].map(&:label), { :data_type => :text, :th => true  }],
            [ I18n.t('reports.series.population'), data['population'], { :data_type => :int }],
          ]
        
        if !data['region'].empty?
          Product.vaccine.all.sort.each do |service|
            usage     = data["#{service.id}_loss"].zip(data["#{service.id}_distributed"]).map { |l, d| l.nil? || d.nil? ? nil : (l.to_i + d.to_i) } 
            loss_rate = data["#{service.id}_loss"].zip(usage).map { |l, u| u.nil? || u.zero? ? nil : 100.0 * l.to_f / u }
            series << [ I18n.t('reports.series.distributed'),   data["#{service.id}_distributed"], { :column_group => service.label, :data_type => :int }]
            series << [ I18n.t('reports.series.usage'),         usage,     { :column_group => service.label, :data_type => :int }]
            series << [ I18n.t('reports.series.loss_rate'),     loss_rate, { :column_group => service.label, :data_type => :pct }]
          end
        end
        
        series
      end
    end

    def percent_of_health_centers_having_fridge_problems_by_date_period_for_area_date_period_range(area, date_period_range)
      data = Queries.health_centers_having_fridge_problems_by_date_period_for_area_date_period_range(area, date_period_range)

      data = Hash[*data.map { |d| [d['date_period'], 100.0 * d['problem_count'].to_f / d['total_health_centers'].to_f] }.flatten]

      [[I18n.t('reports.series.fridges.broken_or_missing'), date_period_range.map { |d| if data[d].nil? || data[d].nan? then nil else data[d] end }],
       [I18n.t('reports.series.target'), date_period_range.map { |d| 10 }]]
    end

    def one_period?(date_period_range)
      date_period_range.last == date_period_range.first
    end

    def base_region?(region)
      region.is_a?(HealthCenter)
    end

    def delivery_spans(minmax_pairs)
      nbsp = "\xC2\xA0".freeze
      ndash = "\xE2\x80\x93".freeze
      minmax_pairs.map { |minmax|
        min, max = minmax.map { |m| Date.parse(m) rescue nil }
        if min && max
          if min == max
            I18n.l(min, :format => :short)
          elsif min.month == max.month
            "%d%s%d%s%s" % [min.day, ndash, max.day, nbsp, I18n.l(max, :format => :month_abbrev)]
          else min && max
            "%d%s%s%s%d%s%s" % [min.day, nbsp, I18n.l(min, :format => :month_abbrev), ndash, max.day, nbsp, I18n.l(max, :format => :month_abbrev)]
          end
        else
          ""
        end
      }
    end

    def delivery_interval(regions, date_period_range, acceptable_interval)
      rg_by_id = Hash[*regions.map { |r| [r.id, r] }.flatten]
      data = Queries.delivery_interval(regions, date_period_range, acceptable_interval).sort_by { |r| rg_by_id[r['id'].to_i] }.transpose_hashes

      if base_region?(regions.first) && one_period?(date_period_range)
        series = [ [ I18n.t('reports.series.delivery_interval.interval'),     data['avg_interval'], { :data_type => :int } ] ]
      else
        series = [
          [ I18n.t('reports.series.delivery_interval.average_interval'),     data['avg_interval']      , { :data_type => :float } ],
          [ I18n.t('reports.series.delivery_interval.min_interval'),         data['min_interval']      , { :data_type => :int } ],
          [ I18n.t('reports.series.delivery_interval.max_interval'),         data['max_interval']      , { :data_type => :int } ],
          [ I18n.t('reports.series.delivery_interval.total_visits'),         data['number_visits']     , { :data_type => :int } ],
          [ I18n.t('reports.series.delivery_interval.number_acceptable', :num => acceptable_interval),  data['number_acceptable'] , { :data_type => :int } ],
          [ I18n.t('reports.series.delivery_interval.percent_acceptable', :num => acceptable_interval), data['number_visits'].zip(data['number_acceptable']).map { |v,a| v.to_f.zero? ? nil : 100.0 * a.to_f / v.to_f }, { :data_type => :pct } ],
        ]
      end

      if one_period?(date_period_range)
        previous_month_span, current_month_span = ['previous', 'current'].map { |t| delivery_spans(data["min_#{t}"].zip(data["max_#{t}"])) }
        return [[I18n.t('reports.series.delivery_interval.previous_month_dates'), previous_month_span, { :data_type => :text }],
                [I18n.t('reports.series.delivery_interval.current_month_dates'), current_month_span, { :data_type => :text }]] +
                  series
      else
        return series
      end
    end
    
    def percent_of_health_centers_visited_for_area_date_period_range(area, date_period_range)
      visits(area, date_period_range, true, 'date_period', date_period_range)
    end

    def percent_of_health_centers_visited_for_region(regions, date_period_range)
      visits(regions.sort, date_period_range, false, regions.first.class.param_name, regions.sort.map(&:id).map(&:to_s))
    end

    def visits(areas, date_period_range, group_by_date_period, range_name, range)
      data = Queries.health_centers_visited_for_area_date_period_range(areas, date_period_range, group_by_date_period)

      total_data  = Hash[*data.map { |d| [d[range_name], d['total_health_centers']] }.flatten]
      visit_data  = Hash[*data.map { |d| [d[range_name], 100.0 * d['visited_health_centers'].to_f / d['total_health_centers'].to_f] }.flatten]
      report_data = Hash[*data.map { |d| [d[range_name], 100.0 * d['reported_health_centers'].to_f / d['total_health_centers'].to_f] }.flatten]

      [[I18n.t('reports.series.total'),        total_data.values_at(*range) ],
       [I18n.t('reports.series.visited'),      range.map { |d| if visit_data[d].nil? || visit_data[d].nan? then nil else visit_data[d] end }],
       [I18n.t('reports.series.not_visited'),  range.map { |d| if report_data[d].nil? || report_data[d].nan? then nil else report_data[d] - visit_data[d] end }],
       [I18n.t('reports.series.not_reported'), range.map { |d| if report_data[d].nil? || report_data[d].nan? then nil else 100 - report_data[d] end }]]
    end

    def stockouts_by_product_date_period_range(area, product, date_period_range)
      provinces = area.regions
      stockouts(Queries.stockouts_by_product_date_period_range(provinces, product, date_period_range), provinces, date_period_range)
    end

    def stockouts_by_product_area_for_date_period_range(products, regions, date_period_range)
      stockouts(Queries.stockouts_by_area_date_period_range(products, regions, date_period_range, false), products, regions, 'id', regions.first.class.param_name, 'id')
    end

    def stockouts_by_area_date_period_range(products, area, date_period_range)
      stockouts(Queries.stockouts_by_area_date_period_range(products, area, date_period_range, true), products, date_period_range)
    end

    def target_coverage_per_region_by_area_date_range(regions, targets, date_period_range)
      targets.sort.map { |t| [t.label, regions.map {|dz|
        c = t.coverage(dz, date_period_range)
        if c.nil? || c.nan? then nil else 100 * c end
      }] }
    end

    def regional_coverage_per_target_by_area_date_range(regions, targets, date_period_range)
      regions.sort.map { |dz| [dz.name, targets.map {|t|
        c = t.coverage(dz, date_period_range)
        if c.nil? || c.nan? then nil else 100 * c end
      }] }
    end

    def stocked_out_health_centers_by_area_date_period_range(type, area, date_period_range)
      stockouts(Queries.stocked_out_health_centers_by_type_area_date_period_range([type], area.regions, date_period_range),
        area.regions, date_period_range)
    end

    def stocked_out_health_centers_by_type_date_period_range(types, area, date_period_range)
      stockouts(Queries.stocked_out_health_centers_by_type_area_date_period_range(types, [area], date_period_range),
        types.map { |t| ProductType.find_by_code(t) }, date_period_range, 'code')
    end

    private

    def stockouts(stockouts, domain, range, domain_column='id', range_database_column='date_period', range_column='to_s')
      stockout_counts = Hash[*stockouts.map { |p|
        ["#{p[domain_column]}:#{p[range_database_column]}", p['visits'].nil? || p['stockouts'].nil? ? nil : p['visits'].to_i > 0 ? 100.0 * p['stockouts'].to_f / p['visits'].to_f : nil]
      }.flatten]

      domain.sort.map { |p| [p.label, range.map { |t|
        stockout_counts["#{p.send(domain_column)}:#{t.send(range_column)}"]
        },
        p.respond_to?(:report_series_options) ? p.report_series_options : {}
      ]}
    end

    def sort_tree_by_parent(tree, key)
      (tree[key] || []).map { |kk|
        [kk] + sort_tree_by_parent(tree, kk['id'])
      }.flatten_once
    end

    def rollup_data(query_data)
      query_data_by_parent_id = query_data.reject { |d| d['id'] == 't' }.group_by { |d| d['parent_id'] }
      data = sort_tree_by_parent(query_data_by_parent_id, '').transpose_hashes

      id_series = data.delete('id') || []
      parent_id_series = data.delete('parent_id') || []

      name_series, class_series = *id_series.map { |i|
        type, id, *rest = i.split ':'
        case type
        when 'm' then  [id, 'date_period']
        when 'dz' then [DeliveryZone.find(id).label, 'delivery_zone']
        when 'hc' then [HealthCenter.find(id).label, 'health_center']
        when 'di' then [District.find(id).label, 'district']
        when 'pr' then [Province.find(id).label, 'province']
        when 't' then  ['Total', nil]
        else raise 'Unknown ID: ' + i
        end
      }.transpose


      return [
          ['id',        id_series,         { :method => lambda { |d, c| d[c.index].gsub(':','-') }, :hidden => true, :use_as_id => true }],
          ['parent_id', parent_id_series,  { :method => lambda { |d, c| if d[c.index].present? then 'child-of-' + c.report.identifier + '--' + d[c.index].gsub(':','-') end }, :hidden => true, :use_as_class => true }],
          ['',          name_series || [], { :data_type => :format, :method => lambda { |r, c| [ r[c.index+1] == 'date_period' ? :date_period : :text, r[c.index]] } }],
          ['',          class_series || [],{ :hidden => true, :use_as_class => true }],
        ], data
    end

    def hc_format_method(test_proc, ok_val, bad_val, basic_class, other_type)
      lambda { |d,c|
        val = d[c.index]
        if val.nil?
          nil
        else
          if d[0].starts_with?('hc')
            ok = test_proc[val]
            [:content_tag, [:span, (ok ? ok_val : bad_val) || val, { :class => (ok ? 'ok' : 'bad') + ' ' + basic_class }] ]
          else
            [other_type, val]
          end
        end
      }
    end

  end
end
