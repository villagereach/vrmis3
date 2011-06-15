class ReportsController < OlmisController
  # NOTE: #target_coverage_map and #stockouts_map do not require login because of
  # Google Maps license restrictions that require them to be publicly available.
  skip_before_filter :check_logged_in, :set_locale, :only => [ :offline_index, :offline_report, :offline_autoeval,
                                                               :target_coverage_map, :stockouts_map ]
  before_filter :set_locale_without_session, :only => [ :offline_index, :offline_report, :offline_autoeval,
                                                        :target_coverage_map, :stockouts_map ]
  before_filter :current_user, :only => [ :target_coverage_map, :stockouts_map ]
  helper :date_period_range
  add_breadcrumb 'breadcrumb.report', 'reports_path', :except => [ :offline_index, :offline_report, :offline_autoeval ]
  add_breadcrumb 'breadcrumb.report', 'offline_reports_path(:province => params[:province], :locale => I18n.locale)', :only => [ :offline_index, :offline_report, :offline_autoeval ]

  def table_object(graph)
    @table_count = (@table_count || 0) + 1
    graph[:table_id] = "table#{@table_count}"
    
    helpers.javascript_tag("table_options['table#{@table_count}'] = { 'columns': '#{graph[:series_dimension]}', 'rows': '#{graph[:x_dimension]}', 'area': '#{graph[:area]}' };\n") +
      Graphs.chart_to_table(graph).html_table(params)
  end
  
  def chart_object(width, height, graph)
    @chart_count = (@chart_count || 0) + 1
    params[:chart_id] = id = "jqplot#{@chart_count}"
    <<-EOD
      <div class="plot" id="#{ id }" style="width:#{width}px; height: #{(height * 1.25).to_i}px;"></div>
      <script type="text/javascript">
        jQuery(
          function(){
            jqplots['#{id}'] = #{ Graphs.chart_to_jqplot(graph.merge(:chart_id => id)) };
            jqplots['#{id}'].orig_data  = jqplots['#{id}'].data;
            jqplots['#{id}'].orig_ticks = jqplots['#{id}'].axes.xaxis.ticks;
            jqplots['#{id}'].x_dimension = '#{graph[:x_dimension]}';
            jqplots['#{id}'].series_dimension = '#{graph[:series_dimension]}';
          });
      </script>
    EOD
  end
  
  def index
  end

  def autoeval
    add_breadcrumb 'breadcrumb.report_autoeval', url_for(:graph => params[:graph])
    @district = params[:district_id] ? District.find(params[:district_id]) : current_user.districts.first
    @autoeval ||= Autoeval.new(current_user, @district.health_centers)
  end

  def self.offline_reports
    %w(visited_health_centers delivery_interval coverage rdt_consumption)
  end
  
  def offline_index
    @suppress_breadcrumbs = true
    render :offline_index, :layout => 'offline'
  end

  def offline_autoeval
    #@suppress_manifest = true
    add_breadcrumb "breadcrumb.offline_report.autoeval"
    if stale?(:last_modified => DataSubmission.last_submit_time.utc)
      render :offline_autoeval, :layout => 'offline'
    end
  end
  
  def offline_report
    @report = params[:report].downcase.gsub(/[^a-z_]+/, '')
    add_breadcrumb "breadcrumb.offline_report.#{@report}"

    vendor_root = File.expand_path(File.join(File.dirname(__FILE__), '..','..'))
    files = Dir.glob(File.join(vendor_root, 'lib', '{graphs,reports,queries}.rb'))
    last_mod_time = (files.map{ |f| File.mtime(f) } << DataSubmission.last_submit_time).max

    text = cache("#{params[:action]}-#{@report}-#{I18n.locale}-#{last_mod_time.to_i}") do
      render_to_string(:action => 'offline_report', :layout => 'offline')
    end
    render(:text => text, :layout => false)
  end
  
  def delivery_interval
    add_breadcrumb 'breadcrumb.report_delivery_intervals', url_for(:graph => 'delivery_interval')
    @date_period_range = helpers.get_date_period_range
    label, dates = helpers.parse_date_period_range
    @area = helpers.get_area_from_params

    @tables = [
      [I18n.t('breadcrumb.report_delivery_intervals'),
        Graphs.delivery_interval(params.merge({
          :date_period_range => @date_period_range }))
      ]
    ]
  end

  def visited_health_centers
    add_breadcrumb('breadcrumb.report_visited_health_centers', url_for(:graph => 'visited_health_centers'))
    
    @date_period_range = helpers.get_date_period_range
    label, dates = helpers.parse_date_period_range
    @area = helpers.get_area_from_params
    @tables = [
      [I18n.t('breadcrumb.report_visited_health_centers'),
        Graphs.visit_counts_health_centers_per_region_by_area_date_period_range(params.merge({
          :date_period_range => @date_period_range }))
      ]
    ]

    @graphs = []

    if (dates.last > dates.first) || @area.class != District
      @graphs << 
        [I18n.t('breadcrumb.report_visited_health_centers'),
        Graphs.visited_health_centers_per_region_by_area_date_period_range(params.merge({
            :date_period_range => @date_period_range }))]
    end
  end

  def fridge_issues
    add_breadcrumb 'breadcrumb.report_fridge_issues', url_for(:graph => 'fridge_issues')
    @date_period_range = helpers.get_date_period_range
    @graphs = [
      [I18n.t('breadcrumb.report_fridge_issues'),
        Graphs.fridge_issues_per_region_by_area_date_period_range(params.merge({:date_period_range => @date_period_range}))]
    ]
  end
  
  def provincial_summary
    add_breadcrumb 'breadcrumb.report_provincial_summary', url_for(:graph => 'provincial_summary')
    @date_period_range = helpers.get_date_period_range
    label, dates = helpers.parse_date_period_range
    
    products  = params[:product_id]  ? Product.trackable.find_all_by_id(params[:product_id]) : Product.trackable

    @area = helpers.get_area_from_params    
    
    @product_id = products.map(&:id)
    graph_params = params.merge({
      :product_id => @product_id,
      :date_period_range => @date_period_range
    })
    
    @tables = [
      [
      @area.label,
        Graphs.stockouts_by_product_area_for_date_period_range(graph_params.merge(:area_id => @area.id))
      ]
    ]  
  end
  
  def fridge_problems
    add_breadcrumb 'breadcrumb.report_stockouts', url_for(:graph => 'stockouts')
    
  end
  
  def stockouts
    add_breadcrumb 'breadcrumb.report_stockouts', url_for(:graph => 'stockouts')
    @date_period_range = helpers.get_date_period_range
    label, dates = helpers.parse_date_period_range
    
    products  = params[:product_id]  ? Product.trackable.find_all_by_id(params[:product_id]) : Product.trackable

    @area = helpers.get_area_from_params    
    
    @product_id = products.map(&:id)
    graph_params = params.merge({
      :product_id => @product_id,
      :date_period_range => @date_period_range
    })
    
    @tables = [
      [
      @area.label,
        Graphs.stockouts_by_product_area_for_date_period_range(graph_params.merge(:area_id => @area.id))
      ]
    ]

    @graphs = [ [I18n.t('reports.titles.stocked_out_health_centers_by_type_and_date_period' + 'woo', :name => @area.label, :date => label),
                Graphs.stocked_out_health_centers_by_type(graph_params)] ]
                
#    if @area.class != District && dates.last > dates.first
#      @tab_graph_dimension = 'product'
#      @tab_graphs = products.sort.map { |p| 
#        [
#          p.label,
#          Graphs.stockouts_per_province_date_period_by_product_date_period_range(graph_params.merge(:product_id => p.id))            
#        ]
#      }
#    end
  end

  def coverage
    add_breadcrumb 'breadcrumb.report_coverage', url_for(:graph => 'coverage')
    @date_period_range = helpers.get_date_period_range
    @target_percentages = (params[:target_percentage_id] || TargetPercentage.all.sort.map(&:id)).map(&:to_i)

    @area = helpers.get_area_from_params
    graph_params = params.merge({
      :target_percentage_id => @target_percentages,
      :date_period_range => @date_period_range
    })
    @graphs = []
    @tables = [
      ['', Graphs.target_coverage_by_area_date_period_range(graph_params) ],
#      ['', Graphs.usage_by_area_date_period_range(graph_params) ],
    ]
  end

  def rdt_consumption
    add_breadcrumb 'breadcrumb.report_rdt_consumption', url_for(:graph => 'rdt_consumption')
    
    @date_period_range = helpers.get_date_period_range
    @area = if params[:province_id] && params[:district_id].nil?
      params[:district_id] ||= District.default.id
      District.default
    else
      helpers.get_area_from_params
    end
    
    @tables = [
      [I18n.t('breadcrumb.report_rdt_consumption'),
        Graphs.rdt_consumption_by_area_date_period_range(params.merge({
          :date_period_range => @date_period_range }))
      ]
    ]

    @graphs = []
  end
  
  def target_coverage_map
    add_breadcrumb 'breadcrumb.report_maps', url_for(:graph => 'maps')
    @date_period_range = helpers.get_date_period_range
    params[:date_period_range] ||= @date_period_range
    label, date_period_range = helpers.parse_date_period_range(params)

    @target_percentage = (params[:target_percentage_id] ?
                          TargetPercentage.find_by_id(params[:target_percentage_id]) : 
                          TargetPercentage.first(:order => 'code asc'))

    @map = Maps.districts_by_target_percentage_for_date_period_range(@target_percentage, date_period_range)
  end

  def stockouts_map
    add_breadcrumb 'breadcrumb.report_maps', url_for(:graph => 'maps')
    @date_period_range = helpers.get_date_period_range
    params[:date_period_range] ||= @date_period_range
    label, date_period_range = helpers.parse_date_period_range(params)

    @products = (params[:product_id] ? 
                  Product.trackable.find_all_by_id(params[:product_id]) :
                  Product.trackable.all)
    
    @map = Maps.districts_by_stockouts_for_date_period_range(@products, date_period_range)
  end

end
