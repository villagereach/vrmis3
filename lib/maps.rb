require 'ostruct'
class Percentage
  def initialize(n)
    @value = n
  end

  def present?
    @value.present?
  end
  
  def nil?
    @value.nil?
  end
  
  def method_missing(sym, *args, &block)
    @value.send(sym, *args, &block)
  end
  
  def to_s
    "%0.1f %%" % (@value * 100) 
  end
end

class Maps
  class << self
    def districts_by_target_percentage_for_date_period_range(target_percentage, date_period_range)
      date_periods = date_period_range.map { |d| (Date.from_date_period(d) - 1.date_period).to_date_period }
      show_map(District.with_location) do |district|
        coverage, total, population = target_percentage.coverage_and_total(district, date_periods)
        population ||= district.population

        [Percentage.new(coverage), <<-INFO]
          <h4>#{district.name}</h4>
          <div id="report_popup">
              #{I18n.t('maps.popup.population')}: #{population}
              <br/>
              #{I18n.t('maps.popup.coverage_percentage', :name => target_percentage.name, :coverage => (100 * coverage.to_f).to_i)}
              <br/>
              #{I18n.t('maps.popup.service_count', :name => target_percentage.name, :total => total)}
          </div>
        INFO
      end
    end

    def districts_by_stockouts_for_date_period_range(products, date_period_range)
      districts = District.with_location
      stockout_rows_by_district_id = 
        Queries.stockouts_by_area_date_period_range(products, districts, date_period_range, false).
          group_by { |row| row['district_id'].to_i }
        
      show_map(districts, true) do |district|
        if stockouts = stockout_rows_by_district_id[district.id]
          total_stockouts = stockouts.sum { |row| row['stockouts'].to_i }
          all_stockouts = stockouts.select { |row| row['stockouts'].to_i > 0 }.map { |row| Product.find(row['id']).label + ': ' + row['stockouts'] }.join("<br />")
          [total_stockouts, <<-INFO]
            <h4>#{district.name}</h4>
            <div id="report_popup">
              #{I18n.t('maps.popup.population')}: #{district.population}
                <br/>
                #{I18n.t('maps.popup.total_stockouts', :stockouts => total_stockouts)}
                <br />
                #{all_stockouts}
            </div>
          INFO
        else
          [nil, %Q{<h4>#{district.name}</h4><div id="report_popup">#{I18n.t('maps.popup.population')}: #{district.population}</div>}]
        end
      end
    end
    
    def map_show_proxy=(p)
      # dependency injection for testing
      @map_show_proxy = p
    end
    
    private
    
    def map_show_proxy
      @map_show_proxy || lambda { |d, i, b| gmaps(d, i, &b) }
    end
    
    def show_map(districts, invert_scale=false, &block)
      map_show_proxy.call(districts, invert_scale, block)
    end
      
    def gmaps(districts, invert_scale, &block)
      if centroid = districts.map(&:centroid).inject { |a, b| [a[0] + b[0], a[1] + b[1]] }.maybe.map { |l| l / districts.length }
        map = GMap.new("map_div")
        map.control_init(:large_map => true,:map_type => true)
    
        n_gon = polygon(20)
        map_points = []
    
        min = districts.map(&:population).compact.min
    
        district_metric_overlays = districts.map { |district|
          metric, overlay = yield district
          [district, metric, overlay]
        }
        
        max_metric = district_metric_overlays.map(&:second).reject(&:nil?).max
        min_metric = district_metric_overlays.map(&:second).reject(&:nil?).min

        max_color = 1.0
        min_color = 0.0
        
        if invert_scale && max_metric
          district_metric_overlays = district_metric_overlays.map { |d, metric, o| 
            [d, metric.present? ? max_metric - metric : nil, o]
          }
          min_metric = 0
          max_color, min_color = min_color, max_color
        end
        
        if max_metric.nil? || max_metric.zero? || max_metric == min_metric
          max_metric = 1.0 
          min_metric = 0.0
        end
        
        district_metric_overlays.each do |district, metric, overlay|
          centroid = district.centroid
    
          scaled_n_gon = n_gon.map { |point| point.map { |l| 0.666 * l * (district.population.to_f / min) ** 0.5 } }.
            map { |point| point.zip(centroid).map(&:sum) }

          color = (metric.present? ? color_code((metric - min_metric) / (max_metric - min_metric)) : '#FFFFFF' rescue raise [max_metric, min_metric, metric].inspect)  
  
          map_points += scaled_n_gon

          map.overlay_init(GPolygon.new(scaled_n_gon, "#000000", 1, 1.0, color, 0.75))
          map.overlay_init(GMarker.new(centroid, :title => district.name, :info_window => overlay.to_s.squish))
        end
        
        if map_points.empty?
          map.center_zoom_init(centroid, 7)
        else
          map.center_zoom_on_bounds_init(bounding_box(map_points).to_a)
        end

        return OpenStruct.new(
          :map => map, 
          :max => max_metric, 
          :max_color => color_code(max_color), 
          :min => min_metric, 
          :min_color => color_code(min_color)
        )
      end
      nil
    end  

    # Determine the bounding box for the given set of points
    def bounding_box(points)
      t = points.transpose

      # north/south extents are simple
      north, south = t[0].max, t[0].min

      # east/west extents need to account for the international date line
      hemis = t[1].partition{|lng| lng >= 0.0}
      hemi_east_min, hemi_east_max = hemis[0].min, hemis[0].max
      hemi_west_min, hemi_west_max = hemis[1].min, hemis[1].max
      east, west = if hemi_east_min.nil?
                     # Completely in western hemisphere
                     [ hemi_west_max, hemi_west_min ]
                   elsif hemi_west_min.nil?
                     # Completely in eastern hemisphere
                     [ hemi_east_max, hemi_east_min ]
                   else
                     # Spanning both eastern and western hemispheres
                     if hemi_east_max - hemi_west_min < hemi_west_max - hemi_east_min + 360
                       # Crossing the prime meridian
                       [ hemi_east_max, hemi_west_min ]
                     else
                       # Crossing the anti meridian
                       [ hemi_west_max, hemi_east_min ]
                     end
                   end

      r = 1e3  # Round to 3 decimal places
      [ [ (south * r).round / r, (west * r).round / r ], [ (north * r).round / r, (east * r).round / r ] ]
    end
    
    def color_code(n)
      "#%02X%02X%02X" % hsv2rgb(120.0 * n, 1.0, 1.0)
    end
    
    def polygon(n)
      # this generates an extra point at the beginning, to complete the polygon
      (0..n).to_a.map { |a| a * 2 * 3.14159265358979 / n }.map { |a| [Math.cos(a) / 10, Math.sin(a) / 10] }
    end
    
    def hsv2rgb(h, s, v)
      h_i = (h/60).to_i % 6  
      f = (h/60) - (h/60).to_i
      p = v * (1.0-s)
      q = v * (1.0-f) * s
      t = v * (1.0 - (1.0 - f) * s)
      
      return case h_i
             when 0 then [v, t, p]
             when 1 then [q, v, p]
             when 2 then [p, v, t]
             when 3 then [p, q, v]
             when 4 then [t, p, v]
             when 5 then [v, p, q]
             end.map { |i| i * 255 }
    end
  end
end

