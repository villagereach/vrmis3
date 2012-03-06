class Graphs
  class << self
    include GraphsHelper

    def rollup(name, params, *args)
      options = parse_params(params)
      {
        :params => params.merge(:graph => name),
        :never_sort => true,
        :groups => [
          {
            :series => Reports.send(name, params[:province_id], options[:date_period_range], *args)
          }
        ]
      }
    end

    def offline_coverage(params)
      rollup('rolled_up_target_coverage_by_province_date_period_range', params)
    end

    def offline_delivery_interval(params)
      rollup('rolled_up_delivery_intervals_by_province_date_period_range', params, 34)
    end

    def offline_visited_health_centers(params)
      rollup('rolled_up_visited_health_centers_by_province_date_period_range', params)
    end

    def offline_stockouts(params)
      rollup('rolled_up_stockouts_by_province_date_period_range', params)
    end

    def offline_fridge_issues(params)
      rollup('rolled_up_fridge_issues_by_province_date_period_range', params)
    end

    def target_coverage_by_area_date_period_range(params)
      options = parse_params(params)
      {
        :params => params.merge(:graph => 'target_coverage_by_area_date_period_range'),
        :x_axis => I18n.t('reports.axes.'+options[:regions].first.class.name.tableize.singularize),
        :area => options[:regions].first.class.name.underscore,
        :title => I18n.t('reports.titles.target_coverage', :name => options[:area].label, :date => options[:label]),
        :groups => [
          :series => Reports.target_coverage_by_area_date_period_range(options[:regions], options[:date_period_range])
        ]
      }
    end
    

    def usage_by_area_date_period_range(params)
      options = parse_params(params)
      {
        :params => params.merge(:graph => 'usage_by_area_date_period_range'),
        :x_axis => I18n.t('reports.axes.'+options[:regions].first.class.name.tableize.singularize),
        :area => options[:regions].first.class.name.underscore,
        :title => I18n.t('reports.titles.usage', :name => options[:area].label, :date => options[:label]),
        :groups => [
          :series => Reports.usage_by_area_date_period_range(options[:regions], options[:date_period_range])
        ]
      }
    end
    
    def fridge_issues_per_region_by_area_date_period_range(params)
      options = parse_params(params)
      {
        :params => params.merge(:graph => 'fridge_issues_per_region_by_area_date_period_range'),
        :area => options[:area].class.name.underscore,
        :title => I18n.t('reports.titles.refrigerator_issues', :name => options[:area].label, :date => options[:label]),
        :x_axis => I18n.t('reports.axes.date_period'),
        :x_labels => options[:date_period_range].to_a,
        :groups => [
          {
            :type => :bar,
            :y_axis => I18n.t('reports.axes.percent_malfunctioning'),
            :series => Reports.percent_of_health_centers_having_fridge_problems_by_date_period_for_area_date_period_range(options[:area], options[:date_period_range])
          }
        ]
      }
    end

    
    def visit_counts_health_centers_per_region_by_area_date_period_range(params)
      options = parse_params(params)
      total, visited, not_visited, not_reported = *Reports.percent_of_health_centers_visited_for_region(options[:regions], options[:date_period_range])

      if Reports.base_region?(options[:regions].first) && Reports.one_period?(options[:date_period_range])
        method = lambda { |data, column|
          if !data[column.index].nil?
            [:span, (data[column.index].to_i == 0 ? I18n.t('reports.series.not_visited') : I18n.t('reports.series.visited')),
              { :class => (data[column.index].to_i == 0 ? 'bad visited' : 'ok visited') }]
          end
        }
        series = [[I18n.t('reports.series.visited'), visited.second, { :data_type => :content_tag, :method => method }]]
      else
        series = [[I18n.t('reports.series.total_clinic_visits'), total.second],
                  [I18n.t('reports.series.reported'), not_reported.second.zip(total.second).map { |a,b| ((100 - a.to_f) * b.to_f/100 + 0.5).to_i }],
                  [visited.first, visited.second.zip(total.second).map { |a,b| (a.to_f * b.to_f/100 + 0.5).to_i }],
                  [I18n.t('reports.series.percent_visited'), visited.second, { :data_type => :pct }]]
      end

      {
        :params => params.merge(:graph => 'visit_counts_health_centers_per_region_by_area_date_period_range'),
        :area => options[:regions].first.class.name.underscore,
        :title => I18n.t('reports.titles.health_centers_visited', :name => options[:area].label, :date => options[:label]),
        :x_dimension => 'region',
        :series_dimension => 'visit_counts',
        :x_labels => options[:regions].map(&:label),
        :groups => [
          {
            :data_type => :int,
            :series => series
          }
        ]
      }
    end

    def visited_health_centers_per_date_period_by_area_date_period_range(params)
      options = parse_params(params)
      total, visited, not_visited, not_reported = *Reports.percent_of_health_centers_visited_for_area_date_period_range(options[:area], options[:date_period_range])
      {
        :params => params.merge(:graph => 'visited_health_centers_per_date_period_by_area_date_period_range'),
        :area => options[:area].class.name.underscore,
        :title => I18n.t('reports.titles.health_centers_visited', :name => options[:area].label, :date => options[:label]),
        :x_axis => I18n.t('reports.axes.date_period'),
        :x_labels => options[:date_period_range].to_a,
        :x_dimension => 'date_period',
        :series_dimension => 'visit_counts',
        :stack_series => true,
        :groups => [
          {
            :type => :line,
            :max    => 100.0,
            :min    => 0.0,
            :step   => 20.0,
            :y_axis => I18n.t('reports.axes.percent_visited'),
            :series => [visited,
                        not_visited,
                        not_reported + [{:fill_alpha => 0.5}],
                        [I18n.t('reports.series.target'), [90] * options[:date_period_range].to_a.length, {:disable_stack => true}]]
          }
        ]
      }
    end

    def visited_health_centers_per_region_by_area_date_period_range(params)
      options = parse_params(params)
      total, visited, not_visited, not_reported = *Reports.percent_of_health_centers_visited_for_region(options[:regions], options[:date_period_range])
      {
        :params => params.merge(:graph => 'visited_health_centers_per_region_by_area_date_period_range'),
        :area => options[:area].class.name.underscore,
        :title => I18n.t('reports.titles.health_centers_visited', :name => options[:area].label, :date => options[:label]),
        :x2axis => [0, options[:regions].length-1, false],
        :x_axis => I18n.t('reports.axes.'+options[:regions].first.class.name.tableize.singularize),
        :x_labels => options[:regions].map(&:label),
        :x_dimension => 'region',
        :series_dimension => 'visit_percentage',
        :stack_series => true,
        :groups => [
          {
            :axis   => :yaxis,
            :type => :bar,
            :max    => 100.0,
            :min    => 0.0,
            :step   => 20.0,
            :y_axis => I18n.t('reports.axes.percent_visited'),
            :series => [visited, not_visited, not_reported]
          },
          {
            :axis   => :yaxis,
            :xaxis  => :x2axis,
            :max    => 100.0,
            :min    => 0.0,
            :step   => 20.0,
            :y_axis => I18n.t('reports.axes.percent_visited'),
            :type => :line,
            :series => [[I18n.t('reports.series.target'), [90] * options[:regions].length, {:disable_stack => true}]]
          }
        ]
      }
    end

    def stockouts_per_province_date_period_by_product_date_period_range(params)
      options = parse_params(params)
      product = options[:products].first
      {
        :params => params.merge(:graph => 'stockouts_per_province_date_period_by_product_date_period_range'),
        :area => options[:area].class.name.underscore,
        :x_axis => I18n.t('reports.axes.date_period'),
        :x_labels => options[:date_period_range].to_a,
        :title => I18n.t('reports.titles.stockouts_by_product_and_date_period', :name => product.label, :date => options[:label]),
        :x_dimension => 'date_period',
        :series_dimension => 'region',
        :groups => [
          {
            :type => :line,
            :max    => 100.0,
            :min    => 0.0,
            :step   => 20.0,
            :y_axis => I18n.t('reports.axes.stockouts'),
            :series => Reports.stockouts_by_product_date_period_range(options[:area], product, options[:date_period_range]),
          }
        ]
      }
    end

    def stockouts_by_product_area_for_date_period_range(params)
      options = parse_params(params)
      regions = options[:regions]
      group_options = regions.first.class.stockout_table_options(options)

      {
        :params => params.merge(:graph => 'stockouts_by_product_area_for_date_period_range'),
        :area => regions.first.class.name.underscore,
        :x_axis => I18n.t('reports.axes.'+regions.first.class.name.underscore),
        :x_labels => regions.map(&:label),
        :title => I18n.t('reports.titles.stockouts_by_area_and_product', :name => options[:area].label, :date => options[:label]),
        :x_dimension => 'region',
        :series_dimension => 'product',
        :groups => [
          {
            :type        => :line,
            :data_type   => :pct,
            :y_axis => I18n.t('reports.axes.stockouts'),
            :series => Reports.stockouts_by_product_area_for_date_period_range(options[:products], regions, options[:date_period_range]),
          }.merge(group_options)
        ]
      }
    end

    def stockouts_per_product_date_period_by_area_date_period_range(params)
      options = parse_params(params)
      {
        :params => params.merge(:graph => 'stockouts_per_product_date_period_by_area_date_period_range'),
        :area => options[:area].class.name.underscore,
        :x_axis => I18n.t('reports.axes.date_period'),
        :x_labels => options[:date_period_range].to_a,
        :title => I18n.t('reports.titles.stockouts_by_area_and_date_period', :name => options[:area].label, :date => options[:label]),
        :x_dimension => 'date_period',
        :series_dimension => 'product',
        :groups => [
          {
            :type => :line,
            :max    => 100.0,
            :min    => 0.0,
            :step   => 20.0,
            :y_axis => I18n.t('reports.axes.stockouts'),
            :series => Reports.stockouts_by_area_date_period_range(options[:products], options[:area], options[:date_period_range]),
          }
        ]
      }
    end

    def stocked_out_health_centers_by_type(params)
      options = parse_params(params)
      {
        :params => params.merge(:graph => 'stocked_out_health_centers_by_type'),
        :area => options[:area].class.name.underscore,
        :x_axis => I18n.t('reports.axes.date_period'),
        :x_labels => options[:date_period_range].to_a,
        :x_dimension => 'date_period',
        :series_dimension => 'product_type',
        :title => I18n.t('reports.titles.stocked_out_health_centers_by_type_and_date_period', :name => options[:area].label, :date => options[:label]),
        :groups => [
          {
            :type => :line,
            :max    => 100.0,
            :min    => 0.0,
            :step   => 20.0,
            :y_axis => I18n.t('reports.axes.percent_stocked_out'),
            :series => Reports.stocked_out_health_centers_by_type_date_period_range(options[:all_product_types], options[:area], options[:date_period_range]),
          }
        ]
      }
    end

    def stocked_out_health_centers_by_area(params)
      options = parse_params(params)
      {
        :params => params.merge(:graph => 'stocked_out_health_centers_by_area'),
        :area => options[:area].class.name.underscore,
        :x_axis => I18n.t('reports.axes.date_period'),
        :x_labels => options[:date_period_range].to_a,
        :x_dimension => 'date_period',
        :series_dimension => 'region',
        :title => I18n.t('reports.titles.stocked_out_health_centers_by_area_and_date_period', :name => options[:area].label, :type => I18n.t(options[:product_type]), :date => options[:label]),
        :groups => [
          {
            :type => :line,
            :max    => 100.0,
            :min    => 0.0,
            :step   => 20.0,
            :y_axis => I18n.t('reports.axes.percent_stocked_out'),
            :series => Reports.stocked_out_health_centers_by_area_date_period_range(options[:product_type], options[:area], options[:date_period_range]),
          }
        ]
      }
    end

    def target_coverage_per_region_by_area_date_range(params)
      options = parse_params(params)
      regions = options[:regions]
      {
        :params => params.merge(:graph => 'target_coverage_per_region_by_area_date_range'),
        :area => regions.first.class.name.underscore,
        :title => I18n.t('reports.titles.target_coverage', :name => options[:area].label, :date => options[:label]),
        :x_axis =>   I18n.t("reports.axes.#{regions.first.class.name.tableize.singularize}"),
        :x_labels => options[:regions].map(&:name),
        :x_dimension => 'region',
        :series_dimension => 'target_percentage',
        :groups => [
          {
            :type => :bar,
            :y_axis => I18n.t('reports.axes.target_coverage'),
            :series => Reports.target_coverage_per_region_by_area_date_range(options[:regions], options[:targets], options[:date_period_range]),
          }
        ]
      }
    end

    def regional_coverage_per_target_by_area_date_range(params)
      options = parse_params(params)
      regions = options[:regions]
      {
        :params => params.merge(:graph => 'regional_coverage_per_target_by_area_date_range'),
        :area => regions.first.class.name.underscore,
        :title => I18n.t('reports.titles.regional_target_coverage', :name => options[:area].label, :date => options[:label]),
        :x_axis =>   I18n.t("reports.axes.target_percentage"),
        :x_labels => options[:targets].map(&:label),
        :x_dimension => 'target_percentage',
        :series_dimension => 'region',
        :groups => [
          {
            :type => :bar,
            :y_axis => I18n.t('reports.axes.target_coverage'),
            :series => Reports.regional_coverage_per_target_by_area_date_range(regions, options[:targets], options[:date_period_range]),
          }
        ]
      }
    end

    def delivery_interval(params)
      options = parse_params(params)
      regions = options[:regions]
      acceptable_interval = 33
      series = Reports.delivery_interval(regions, options[:date_period_range], acceptable_interval)

      if Reports.base_region?(options[:regions].first) && Reports.one_period?(options[:date_period_range])
        series.last.last.merge!(
          :data_type => :content_tag,
          :method => lambda { |d, c|
            if d[c.index] && d[c.index].to_i <= acceptable_interval
              [:span, d[c.index].to_i, { :class => 'ok visited' }]
            elsif d[c.index]
              [:span, d[c.index].to_i, { :class => 'bad visited' }]
            end
          } )
      end

      {
        :params => params.merge(:graph => 'delivery_interval'),
        :area => regions.first.class.name.underscore,
        :title => I18n.t('reports.titles.delivery_interval', :name => options[:area].label, :date => options[:label]),
        :x_axis =>   I18n.t("reports.axes.#{regions.first.class.name.tableize.singularize}"),
        :x_labels => options[:regions].map(&:label),
        :x_dimension => 'region',
        :series_dimension => 'interval_statistic',
        :groups => [ { :series => series } ]
      }
    end
  end
end
