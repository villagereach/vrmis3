module ProgressHelper
  ProgressClasses = { 
    HealthCenterVisit::REPORT_COMPLETE    => 'complete',
    HealthCenterVisit::REPORT_INCOMPLETE  => 'incomplete',
    HealthCenterVisit::REPORT_NOT_DONE    => 'todo',
    HealthCenterVisit::REPORT_NOT_VISITED => 'not_visited',
    HealthCenterVisit::REPORT_IRRELEVANT  => 'irrelevant',
    nil => 'todo',
  }
    
  def progress_class(progress_code)
    ProgressClasses[progress_code]
  end

  def progress_class_for_task(visit, task)
    progress_class(visit.status_by_table(HealthCenterVisit::TASKS_AND_TABLES[task]))
  end

  def progress_class_for_visit(visit)
    progress_class(visit.overall_status)
  end
 
  def progress_fraction(visit)
    p = visit.progress_numbers
    "#{p.first}/#{p.second}"
  end
      

  def progress_bar_image(type, alt, size)
    dim = case size.to_s
          when "small"  : "12x12"
          when "normal" : "16x16"
          when "large"  : "20x20"
          when "huge"   : "24x24"
          end
    image_tag("progress/#{type}_#{size}.png", :size => dim, :alt => alt)
  end
  def progress_complete(size)
    progress_bar_image(:complete, "o", size)
  end
  def progress_incomplete(size)
    progress_bar_image(:incomplete, "&ndash;", size)
  end
  def progress_did_not_visit(size)
    progress_bar_image(:did_not_visit, "&ndash;", size)
  end
  
  def progress_todo(size)
    progress_bar_image(:todo, "&times;", size)
  end
  
  def progress_irrelevant(size)
    progress_bar_image(:irrelevant, "&nbsp;", size)
  end
  
  

  def progress_bar_field(report_status, title, size = "normal")
    case report_status
    when HealthCenterVisit::REPORT_IRRELEVANT
      content_tag(:span, progress_irrelevant(size),    :class => :irrelevant, :title => title)
    when HealthCenterVisit::REPORT_COMPLETE
      content_tag(:span, progress_complete(size),      :class => :complete, :title => title)
    when HealthCenterVisit::REPORT_INCOMPLETE
      content_tag(:span, progress_incomplete(size),    :class => :incomplete, :title => title)
    when HealthCenterVisit::REPORT_NOT_VISITED
      content_tag(:span, progress_did_not_visit(size), :class => :complete, :title => title)
    when HealthCenterVisit::REPORT_NOT_DONE
      content_tag(:span, progress_todo(size), :class => :empty, :title => title)
    else
      raise "Unknown report status: #{report_status}"
    end
  end

  
  
  def progress_bar_per_batch(health_center, options = {})
    icon_size = options[:size] || "normal"

    # Visit
    title = I18n.t('visits.health_center_monthly_tasks.visit')
    contents, status = if visit = HealthCenterVisit.find_by_health_center_id_and_visit_month(health_center.id, visit_month)
                         [ content_tag(:span, progress_complete(icon_size), :class => :complete, :title => title), visit.status_by_table ]
                       else
                         [ content_tag(:span, progress_todo(icon_size), :class => :empty, :title => title), Hash.new(HealthCenterVisit::REPORT_NOT_DONE) ]
                       end

    # Inventory
    contents << progress_bar_field(status['HealthCenterInventory'],
                                   I18n.t('visits.health_center_monthly_tasks.inventory'),
                                   icon_size)

    # General Equipment
    contents << progress_bar_field(status['GeneralEquipment'],
                                   I18n.t('visits.health_center_monthly_tasks.general'),
                                   icon_size)

    # Cold Chain
    contents << progress_bar_field(status['ColdChainEquipment'],
                                   I18n.t('visits.health_center_monthly_tasks.cold_chain'),
                                   icon_size)

    # Stock Cards
    contents << progress_bar_field(status['StockCardEquipment'],
                                   I18n.t('visits.health_center_monthly_tasks.stock_cards'),
                                   icon_size)

    # EPI Tallies
    [ EpiUsageTally, AdultVaccinationTally, ChildVaccinationTally, FullVaccinationTally, RdtTally ].each do |tally_klass|
      title = tally_klass.tally_name  # TODO: Localize
      contents << progress_bar_field(status[tally_klass.to_s], title, icon_size)
    end

    contents
  end

  def progress_bar_per_batch_group(health_center, options = {})
    icon_size = options[:size] || "normal"

    # Visit
    title = I18n.t('visits.health_center_monthly_tasks.visit')
    contents, status = if visit = HealthCenterVisit.find_by_health_center_id_and_visit_month(health_center.id, visit_month)
                         [ content_tag(:span, progress_complete(icon_size), :class => :complete, :title => title), visit.status_by_table_group ]
                       else
                         [ content_tag(:span, progress_todo(icon_size), :class => :empty, :title => title), {} ]
                       end

    # Inventory
    contents << progress_bar_field(status['Inventory'], I18n.t('visits.health_center_monthly_tasks.inventory'), icon_size)

    # Equipment
    contents << progress_bar_field(status['Equipment'], I18n.t('visits.health_center_monthly_tasks.equipment'), icon_size)

    # EPI Tallies
    contents << progress_bar_field(status['EPI'], I18n.t('EPI'), icon_size)

    contents
  end
  
 

  def progress_status_for_health_center(health_center, month = nil)
    month ||= visit_month
    HealthCenterVisit.find_by_health_center_id_and_visit_month(health_center.id, month).
      maybe.overall_status || HealthCenterVisit::REPORT_NOT_DONE
  end

  def progress_icon_for_health_center(health_center, options = {})
    icon_size = options[:size] || "normal"
    progress_bar_field(progress_status_for_health_center(health_center), health_center.name, icon_size)
  end

  def progress_bar_for_district(health_centers, options = {})
    hcs = health_centers.map(&:health_center)
    
    statuses = hcs.map{ |hc|
      { :name => hc.name,
        :code => hc.code,
        :status => progress_status_for_health_center(hc),
        :progress => progress_icon_for_health_center(hc, options) }
    }
    
    statuses = (statuses.sort_by{|hsh| [ hsh[:status], hsh[:name] ]} rescue raise statuses.inspect)
    
    if options[:group]
      separator = options[:separator] || "<br />"
      statuses.group_by{|hsh| hsh[:status]}.map{|k,v| status_icons_from_list(v, options)}.join(separator)
    else
      status_icons_from_list(statuses, options)
    end
  end

  def status_icons_from_list(statuses, options)
    statuses.map do |s|
      if options[:link]
        link_to(s[:progress], health_center_visit_path(:health_center => s[:code], :visit_month => visit_month))
      else
        s[:progress]
      end
    end.join
  end

  def progress_status_for_district(district, health_centers, visit_month)
    visits = HealthCenterVisit.find_all_by_health_center_id_and_visit_month(health_centers, visit_month)
    return HealthCenterVisit::REPORT_NOT_DONE if visits.length == 0
    return HealthCenterVisit::REPORT_INCOMPLETE unless visits.length == health_centers.length

    status = visits.map(&:overall_status).uniq
    return status.first if status.length == 1

    HealthCenterVisit::REPORT_INCOMPLETE
  end

  def progress_icon_for_district(district, health_centers, visit_month, options = {})
    icon_size = options[:size] || "normal"
    icon_title = options[:title] === false ? nil : district.name
    progress_bar_field(progress_status_for_district(district, health_centers, visit_month), icon_title, icon_size)
  end

  def progress_by_district_for_month(month, health_centers, options = {})
    health_centers.group_by{|hc|
      hc.health_center.district
    }.map{|d,hcs|
      { :name => d.name,
        :status => progress_status_for_district(d, hcs, month),
        :progress => progress_icon_for_district(d, hcs, month, options) }
    }
  end

  def progress_bar_for_month(month, health_centers, options= {})
    progress_by_district_for_month(month, health_centers, options).sort_by{|hsh|
      [ hsh[:status], hsh[:name] ]
    }.map do |s|
      if options[:link]
        link_to(s[:progress])  # TODO: Where to link
      else
        s[:progress]
      end
    end
  end

  def progress_for_month_per_district(month, health_centers, options = {})
    progress_by_district_for_month(month, health_centers, options.merge(:title => false)).sort_by{|hsh|
      [ hsh[:status], hsh[:name] ]
    }
  end
  
  def progress_status_for_month(month, health_centers)
    status = health_centers.group_by(&:district).map{|d,hcs| progress_status_for_district(d, hcs, month) }.uniq
    status.length == 1 ? status.first : HealthCenterVisit::REPORT_INCOMPLETE
  end    
  
  def progress_icon_for_month(month, health_centers, options = {})
    icon_size = options[:size] || "normal"
    progress_bar_field(progress_status_for_month(month, health_centers), nil, icon_size)
  end

  def named_route_for_step(name, path_params)
    {
      'HealthCenterInventory'          => health_center_inventory_url(path_params),
      'GeneralEquipment'               => health_center_equipment_general_url(path_params),
      'ColdChainEquipment'             => health_center_equipment_coldchain_url(path_params),
      'StockCardEquipment'             => health_center_equipment_stockcards_url(path_params),
      'EpiUsageTally'                  => health_center_usage_epi_url(path_params),
      'AdultVaccinationTally'          => health_center_adult_epi_url(path_params),
      'ChildVaccinationTally'          => health_center_child_epi_url(path_params),
      'FullVaccinationTally'           => health_center_full_epi_url(path_params),
      'RdtTally'                       => health_center_rdt_epi_url(path_params)
    }[name.to_s] || health_center_visit_url(path_params)
  end

  def progress_calculator
    @progress ||= HealthCenterVisitPeriodicProgress.new
  end
end
