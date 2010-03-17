module GraphsHelper
  def chart_to_csv(options)
    FasterCSV.generate do |csv|
      csv << [options[:title]]
      csv << []
      options[:groups].each do |g|

        column_headers = g[:series].map { |s| (s[2] || {}) }
        columns_by_header = column_headers.partition_by { |o| o[:column_group] }
        if columns_by_header.length > 1
          row = []
          columns_by_header.each do |header, cols|
            row += [header.to_s] + [''] * (cols.length - 1)
          end
          csv << row
        end

        csv << (options[:x_labels] ? [options[:x_axis]] : []) + g[:series].map(&:first)
        max = g[:series].map(&:second).map(&:length).max || 1
        0.upto(max-1) do |i|
          csv << (options[:x_labels] ? [options[:x_labels][i]] : []) + 
            g[:series].map do |name, values, series_options|
              if series_options && series_options[:data_type] == :int
                values[i].to_i
              else
                values[i]
              end
            end
        end
        csv << [""]
      end
    end
  end

  def chart_to_table(options, extra_options = {})
    g = options[:groups].first
    data = []        
    max = g[:series].map(&:second).compact.map(&:length).max || 1

    columns = []
    data = (0...max).map { |m| [] }
    x_offset = 0

    if options[:x_labels]
      x_offset = 1
      0.upto(max-1) do |i|
        data[i] << options[:x_labels][i]
      end
      columns << [options[:x_axis], false, :text, lambda { |x| x[0] }, { :th => true }]
    end

    0.upto(max-1) do |i|
      data[i] += g[:series].map do |name, values, series_options| values ? values[i] : nil end
    end

    columns += 
        g[:series].map_with_index { |series, i|
          label, series_data, series_options = *series
          type = (series_options ? series_options.delete(:data_type) : nil) || g[:data_type] || :float
          method = (series_options ? series_options.delete(:method) : nil) || g[:method] || lambda { |x| x[i+x_offset] }
          [label, false, type, method, series_options || {}]
      }

    ReportTable.new(columns, data, :title => options[:title], :identifier => extra_options[:identifier] || options[:table_id], :never_sort => !!options[:never_sort])
  end
  
  class Renderer
    def initialize(x)
      @to_render = x
    end

    def to_json(x)
      'jQuery.jqplot.' + @to_render
    end
  end
  
  def chart_to_jqplot(options)
    id = options[:chart_id]
    
    jqplot = {
      'series' => [],          
      'stackSeries' => !!options[:stack_series],
      'title' => options[:title],
      'legend' => {
        'show' => true,
        'position' => "ne", # or "nw" or "se" or "sw"
#        'margin' => 10, # number of pixels or [x margin, y margin]
#        'backgroundColor' => nil, # or color
        'backgroundOpacity' => 0.5, #number between 0 and 
      },
      'axes' => {
        'xaxis' => {
          'min' =>  0,    #or number
          'max' =>  options[:x_labels].length - 1, #or number
          'labelRenderer' => Renderer.new('CanvasAxisLabelRenderer'),
          'labelOptions'  => { 'enableFontSupport' => true },
          'label' => options[:x_axis],
          'showLabel' => true,
          'ticks' =>  (options[:x_labels]).map_with_index { |v, i| [i, v] }, #null or number or ticks array or '(fn' =>range -> ticks array)
          'tickRenderer' => Renderer.new('CanvasAxisTickRenderer'),
          'tickOptions'  => { 'enableFontSupport' => true },
        },
      }
    }

    if options[:x2axis]
      jqplot['axes']['x2axis'] = 
        {
          'min' =>   options[:x2axis][0],
          'max' =>   options[:x2axis][1],
          'showTicks' =>  options[:x2axis][2],
        }
    end
    
    if options[:stack_series]
      jqplot['seriesDefaults'] = { 'fill' => true, 'showMarker' => false }
    end
    
    if jqplot['axes']['xaxis']['ticks'].map { |v, l| l.length }.any? { |l| l > 80 / options[:x_labels].length }
      jqplot['axes']['xaxis']['tickOptions']['angle'] = 30
      jqplot['axes']['xaxis']['tickOptions']['labelPosition'] = 'middle'
    end
    
    axes = ['yaxis', 'y2axis']
    data = []

    if options[:groups].any? { |g| g[:type] == :bar }
      jqplot['axes']['xaxis']['renderer'] = Renderer.new('CategoryAxisRenderer')
      jqplot['axes']['xaxis']['ticks'] = jqplot['axes']['xaxis']['ticks'].map(&:last) 
    end
      
    
    options[:groups].each do |g| 
      axis = g[:axis] || axes.shift
      min, max, step = y_range(g[:series]) unless g[:max] && g[:min]
      
      jqplot['axes'][axis] = {
        'min' =>  g[:min] || min,        
        'max' =>  g[:max] || max, #or number
        'label' => g[:y_axis],
        'showLabel' => true,
        'labelRenderer' => Renderer.new('CanvasAxisLabelRenderer'),
        'labelOptions'  => { 'enableFontSupport' => true, 'fontSize' => '10pt' },
        'tickInterval' => g[:step] || step,
      }

      g[:series].each do |name, values, series_options|
        series = {}
        series_options ||= {}
        
        if g[:type] == :line
#          series['renderer'] = Renderer.new('LineRenderer')
          series['breakOnNull'] = true
        elsif g[:type] == :bar
          series['renderer'] = Renderer.new('BarRenderer')
          values = [nil] + values
#          series['rendererOptions'] = { 'barPadding' => 8, 'barMargin' => 20}
        end
        
        series['label'] = name
        
        if options[:stack_series] && series_options[:disable_stack] 
          series['disableStack'] = true
          series['fill'] = false
        end

        series['fillAlpha'] = series_options[:fill_alpha] if series_options[:fill_alpha]
        
        series['xaxis'] = g[:xaxis] if g[:xaxis]
        
        vals = values.first.is_a?(Array) ? values : values.map_with_index { |v, i| [i, v] }
        if options[:stack_series]
          vals = vals.map { |i, v| [i, v || 0] }
        end
        
        data << vals
        jqplot['series'] << series
      end
    end

    "jQuery.jqplot('#{id}', #{data.to_json}, #{jqplot.to_json})"
  end

  def interpolated_labels(labels)
    step_size = [1, labels.length / 5].max

    interpolated = []
    labels.each_with_index do |w, i|
      if i % step_size == 0
        interpolated[i] = w.to_s 
      else
        interpolated[i] = 'x'
      end
    end
    
    interpolated
  end
  
  def y_range(series_group)
    max = series_group.map(&:second).map { |m| m.map(&:to_f).reject(&:nan?).max }.map(&:to_f).max
    if max && max > 1
      step = max.to_s.gsub(/(.)[1-9]/, '\10').gsub(/(.)[1-9]/, '\10').to_i / 5.0
      
      return 0, max.to_f * 1.1, step
    else
      return 0, max.to_f * 1.1, max.to_f / 5
    end    
  end
  
  def chart_to_json(options)
    title = Title.new(options[:title])    
    chart = OpenFlashChart.new

    chart.set_title(title)
    chart.x_axis = xa = XAxis.new

    xa.labels = interpolated_labels(options[:x_labels])

    color = [00,00,00]
    
    options[:groups].each do |g|    
      chart.y_axis = ya = YAxis.new
      ya.set_range(*y_range(g[:series]))
      
   
      g[:series].sort_by(&:first).each do |name, values|
        line = case g[:type]
                when :line then LineHollow.new
                when :bar  then BarGlass.new
                else raise "Unknown graph type #{g[:type]}"
                end

        line.text = name
        line.font_size = 10

        line.colour = "%02X%02X%02X" % color
        color = next_color(*color)
        
        line.values = values
        chart.add_element(line)
      end
    end
    
    chart.to_s
  end    
  
  def next_color(r,g,b)
    [g + 211, b + 83, r + 43].map { |i| i % 230 }
  end

  include DatePeriodRangeHelper
  include ApplicationHelper
  
  def parse_params(params)
    options = {}
    params[:date_period_range] ||= default_date_period_range
    options[:label], options[:date_period_range] = parse_date_period_range(params)
    options[:area]              = get_area_from_params(params)
    options[:products]          = Product.trackable.find_all_by_id(params[:product_id]).sort
    options[:regions]           = options[:area].regions.sort
    options[:targets]           = TargetPercentage.find_all_by_id(params[:target_percentage_id]).sort
    options[:all_product_types] = ProductType.all(:conditions => { :trackable => true }).map(&:code)
    options[:product_type]      = params[:type]
    options
  end
end
