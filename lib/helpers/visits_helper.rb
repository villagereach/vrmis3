module VisitsHelper
  def health_center
    @health_center
  end

  def visit_month(p=params)
    p[:visit_month] rescue nil
  end

  def epi_month(p=params)
    (Date.parse(visit_month(p) + '-01') - 1.month).to_date_period
  end
  
  def hcv_label_with_month(visit)
    visit.health_center.name + ', ' + hcv_month(visit.visit_month)
  end 

  def hcv_label_with_month_and_date(visit)
    hcv_label_with_month(visit) +' '+ I18n.l(visit.date, :format=>:short)
  end 

  def hcv_label_with_month_and_new(health_center, visit_month)
    health_center.name + ', ' + hcv_month(visit_month) + ' ' + t('visits.new_visit') 
  end 

  def hcv_best_starting_url(visit, options = {})
    return named_route_for_step(visit, options) if visit.nil?
    named_route_for_step(visit.first_unvisited_step, :health_center => visit.health_center.code, :visit_month => visit.visit_month)
  end
    
  def categorized_nav
    [ [ I18n.t('visits.health_center_monthly_tasks.visit'), 
        [ [:visit, [I18n.t('visits.health_center_monthly_tasks.visit'), health_center_visit_path]]]],
      [ I18n.t('EPI'), 
        [ [:usage, [I18n.t('epi.usage'), health_center_usage_epi_path]],
          [:adult, [I18n.t('epi.adult'), health_center_adult_epi_path]],
          [:child, [I18n.t('epi.child'), health_center_child_epi_path]],
          [:full,  [I18n.t('epi.full'),  health_center_full_epi_path]],
          [:rdt,   [I18n.t('epi.rdt' ),  health_center_rdt_epi_path]]]],    
      [ I18n.t('visits.health_center_monthly_tasks.inventory'),
        [ [:inventory, [I18n.t('visits.health_center_monthly_tasks.inventory'), health_center_inventory_path] ] ] ],
      [ I18n.t('visits.health_center_monthly_tasks.equipment'), 
        [ [:general, [I18n.t('visits.health_center_monthly_tasks.general'), health_center_equipment_general_path ] ],
          [:cold_chain, [I18n.t('visits.health_center_monthly_tasks.cold_chain'), health_center_equipment_coldchain_path ] ],
          [:stock_cards, [I18n.t('visits.health_center_monthly_tasks.stock_cards'), health_center_equipment_stockcards_path ] ] ] ],
    ]
  end
  
  def save_and_continue
    content_tag( 'p',
      submit_tag(t('save')) + (
        if link = next_link
          submit_tag(t('visits.health_center_monthly_tasks.save_and_go_to', :next_page => link.first), :name => 'save_and_continue')
        else
          ''
        end
      ), :class => 'save_and_continue'
    )
  end
  
  def links_sequence
    categorized_nav.map(&:last).flatten_once
  end
  
  def normalize_link(l)
    l.gsub(/\?.*/,'')
  end
  
  def current_link
    @current ||= links_sequence.detect { |l| normalize_link(*l.last.last) == normalize_link(controller.request.path) }.maybe.last
  end
  
  def current_visit_link?(link)
    begin
      normalize_link(link.last) == normalize_link(current_link.last)
    rescue
      false      
    end
  end
  
  def next_link
    links = links_sequence.select { |l| @controller.current_visit.availability_class(l.first) != 'unavailable' }.map(&:last)
    hash = Hash[*([''] + links.map { |l| normalize_link(l.last) }).zip(links + [nil]).flatten_once]
    hash[normalize_link(controller.request.path)]
  end
  
  def tally_table(tally_class, tally_field_proc = nil)
    tally_field_proc ||= lambda { |point| tally_field(tally_class.name, tally_class.param_name(point)) }

    row_groups, col_groups = tally_class.form_table(:standard)

    col_group_combinations = col_groups.map { |cg| Enumerable.multicross(*cg.map { |col| tally_class.possible_key_values(col) }) }.flatten_once
    row_group_combinations = row_groups.map { |cg| Enumerable.multicross(*cg.map { |row| tally_class.possible_key_values(row) }) rescue raise cg.inspect;  }.flatten_once

    column_headers = 
      col_group_combinations.transpose.map { |a| 
        aa = a.partition_by { |i| i }; 
        content_tag(:tr, [content_tag(:th, "", :class => "empty")] + 
          aa.map { |k, vs| 
            column_header = tally_class.header_for(*k) 
            content_tag(:th, content_tag(:div,content_tag(:span, column_header)), :colspan => vs.length) 
          })
      }

    body =           
      row_group_combinations.map do |rg|
        row_headers = rg.map { |type, value| tally_class.header_for(type, value) }
        header = content_tag(:th, content_tag(:div,content_tag(:span, row_headers.join(", "))))
        content_tag(:tr, 
          header + 
            col_group_combinations.map { |cg|
              name = tally_class.param_name(rg + cg)

              if tally_class.category_excluded?(Hash[*(rg + cg).flatten]) 
                content = ""
              else
                content = tally_field_proc[rg + cg]
              end
              
              content_tag(:td, content)
            }.join("")
        )
      end
    
      content_tag(:table, content_tag(:thead, column_headers) + content_tag(:tbody, body), :class => 'spreadsheet')
  end

  def tally_form_field(type, name, field, value, options)
    case type.fields_hash[field.to_sym]
    when :date
      text_field(type.name, name, options.merge({ :value => value, :size => 8, :class => "datepicker" }))
    else
      text_field(type, name, options.merge({ :value => value.to_s, :size => 4 }))
    end
  end
    
  def tally_field(type, name, options={})
    @record_value_hash ||= {}
    @errors ||= {}
    
    type_klass = type.constantize
    
    @record_value_hash[type] ||= type_klass.records_by_param_names_for_keys(@health_center, epi_month)
    dim, field = name.split(':', 2)
    field ||= 'value'
    
    value = (params.has_key?(type) ? params[type][name] : nil) || 
      @record_value_hash[type][name].maybe.send(field)
    
    checked = @record_value_hash[type].has_key?(name) && @record_value_hash[type][name].send(field).nil?
      
    if @mode == 'edit'
      %Q{<div class="tally #{@errors[type] && @errors[type][name] ? 'error' : ''}">} + 
      tally_form_field(type_klass, name, field, value, options) + 
        '' + 
        check_box(type, name + '/NR', :checked => checked) + 
        label(type, name + '/NR', t('NR')) + 
        '</div>'
    else
      "<span id='#{type}[#{name}]'>#{value || (@record_value_hash[type][name] ? 'NR' : '')}</span>"
    end
  end

  def options_for_visits_month(date)
    today = Date.parse(date)
    months_to_show = returning Array.new do |arr|
      (0..11).each do |i|
        arr << [ %Q{#{t(".select_month_value", 
          :epi_month => I18n.localize(today - (i+1).months, :format => "%b %Y"), 
          :visit_month => I18n.localize(today - i.months, :format => "%b %Y"))}}, 
        (today - i.months).to_date_period ]
      end
    end

    options_for_select(months_to_show, visit_month)
  end                                                                                

  def default_field_value(params, index, field, default_value)
    value_from_params = (params ? params[index][field] : nil) || default_value
  end

end
