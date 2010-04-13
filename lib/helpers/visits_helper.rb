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
        HealthCenterVisit.tally_hash.map { |k, v|
          [k, [I18n.t("visits.health_center_monthly_tasks.#{k.underscore}"), health_center_tally_path(:tally => k)]]
        }
      ],
      [ I18n.t('visits.health_center_monthly_tasks.inventory'),
        HealthCenterVisit.inventory_screen_hash.map { |k, v|
          [k, [I18n.t("visits.health_center_monthly_tasks.#{k}"), health_center_inventory_path(:screen => v)] ]
        } ],
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
  
  def tally_table(tally_class, tally_field_proc = nil, header_proc = nil)
    header_proc ||= lambda { |val1, val2| tally_class.header_for(val1, val2) }
    tally_field_proc ||= lambda { |point| tally_field(tally_class.name, tally_class.param_name(point)) }

    row_groups, col_groups = tally_class.form_table(:standard)

    col_group_combinations = col_groups.map { |cg| Enumerable.multicross(*cg.map { |col| tally_class.possible_key_values(col) }) }.flatten_once
    row_group_combinations = row_groups.map { |cg| Enumerable.multicross(*cg.map { |row| tally_class.possible_key_values(row) }) rescue raise cg.inspect;  }.flatten_once

    column_blocks = 
      col_group_combinations.transpose.map { |a| 
        aa = a.partition_by { |i| i }; 

        aa.map { |k, vs| 
          column_header = header_proc[*k] 
          [column_header, vs.length] 
        }
      }

    colgroups = content_tag(:colgroup, nil, :span => 1) + 
      column_blocks.first.map { |header, length|
        content_tag(:colgroup, nil, :class => 'group', :span => length)
      }.join('')
      
    column_headers = 
      column_blocks.map { |block|
        content_tag(:tr, [content_tag(:th, "", :class => "empty")] + 
          block.map { |header, length|
            content_tag(:th, content_tag(:div,content_tag(:span, header)), :colspan => length)
          }
        )
      }
    
    body =
      row_group_combinations.map do |rg|
        row_headers = rg.map { |type, value| header_proc[type, value] }
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
    
      content_tag(:table, colgroups + content_tag(:thead, column_headers) + content_tag(:tbody, body), :class => 'spreadsheet')
  end

  def target_group_form_field(code)
    # Inserts a read-only field containing the expected target group size for the selected health center,
    # for the target percentage identified by the first argument.

    if target = TargetPercentage.find_by_code(code)
      size = (@health_center.catchment_population * target.percentage / Date.date_periods_per_year / 100).to_i
      text_field_tag(code + '_target', size, :disabled => 'disabled', :size => [3, size.to_s.length + 1].max )
    end
  end

  def coverage_field(name, target_code, total)
    # Given a target percentage code and a total-vaccinations cell, inserts a field that calculates the coverage based on the target population size
    if target = TargetPercentage.find_by_code(target_code)
      size = (@health_center.catchment_population * target.percentage / Date.date_periods_per_year / 100).to_i
      expression_field(name, "100 * #{total} / #{size}", '%')
    end
  end
  
  def wastage_field(package_code, open_vials, total_doses)
    # Given a package code and a total-vaccinations cell, inserts a field that calculates the wastage based on the number of doses in the package
    if package = Package.find_by_code(package_code)
      expression_field("#{package_code}_wastage", "100 * ((#{open_vials}) - ((#{total_doses}) / #{package.quantity})) / (#{open_vials})", "%")
    end
  end
  
  def expression_field(name, expression, suffix='')
    # Inserts a calculated field based on the value of other fields.  The second argument should be a
    # Javascript expression where any words starting with an alphabetic character must be the IDs of
    # other fields in the page -- this will be evaluated as the floating point value of those fields.
    # You cannot therefore use reserved words or call Javascript functions unless the name begins with
    # an underscore.
    #
    # If the resulting value is NaN, the field will appear blank. Otherwise, the value will be truncated
    # to an integer and the value of the third argument, if any, will be appended.

    tokens = expression.split(/([a-z][^ \(\)]+)/i) # every field starts with an alpha and contains no spaces
    tokens.push('') if tokens.length % 2 == 0

    fields = tokens.map_with_index { |t, i| i % 2 == 1 ? t : '' }.reject(&:blank?).uniq

    output = '<div style="text-align: center">' + text_field_tag(nil, '', :disabled => 'disabled', :size => 3, :id => name) + '</div>'

    fnname = "_calculate_#{name.gsub(/\W+/, '_')}"
    fn = "function #{fnname}() { \nv = parseInt(" +
      tokens.map { |f|
        if fields.include?(f)
          'parseFloat(0 + $("#' + f + '").val())'
        else f
        end
      }.join("") +
        "); \n$('##{name}').val(isNaN(v) ? '' : (v + '#{suffix}')); $('##{name}').change(); }"

      output + javascript_tag(fn + "\njQuery(document).ready(#{fnname}); \n" +
        "jQuery(document).ready(function() {" + fields.map { |f| "\n$('##{f}').change(#{fnname}); " }.join("") + "\n});")
  end

  def tally_form_field(type, name, options)
    @record_value_hash ||= {}
    
    @record_value_hash[type] ||= type.records_by_param_names_for_keys(@health_center, epi_month)
    
    dim, field = name.split(':', 2)
    field ||= 'value'

    value = (params.has_key?(type.name) ? params[type.name][name] : nil) || 
      @record_value_hash[type][name].maybe.send(field)
    
    nr_checked = @record_value_hash[type].has_key?(name) && @record_value_hash[type][name].send(field).nil?
      
    tf = case type.fields_hash[field.to_sym]
         when :date
           o = options.merge({ :value => value, :size => 8, :class => "datepicker" })
           ActionView::Helpers::InstanceTag.new(type.name, name, self).to_input_field_tag("date", o)
         else
           o = options.merge({ :value => value.to_s, :size => 4, :min => '0', :step => '1', :id => type.name + '_' + name.gsub(/[,:\]]/,'-') })
           ActionView::Helpers::InstanceTag.new(type.name, name, self).to_input_field_tag("number", o)
         end
         
     tf + content_tag(:div,
       check_box(type, name + '/NR', :checked => nr_checked) + 
        label(type, name + '/NR', t('NR')), :class => 'nr')
  end
    
  def tally_form_erb(type, name, options)
    "<%= tally_form_field(#{type.name}," + [name, options].map(&:inspect).join(", ") + ") %>"
  end

  def tally_field(type, name, options={}, form_field_proc=:tally_form_field)
    dim, field = name.split(':', 2)
    field ||= 'value'
    type = type.constantize
    field_type = type.fields_hash[field.to_sym] == :date ? 'date' : 'tally'
    %Q{<div class="#{field_type}" id="#{name.gsub(/[,:]/,'-')}">} + self.send(form_field_proc, type, name, options) + '</div>'
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

  def nr_field(builder, name, index, value, nr_checked, error, suppress_nr = false)
    content_tag(:div,
      builder.text_field(name, :index => index, :value => value, :type => 'number', :min => '0', :step => 1 ) +
        (suppress_nr ? '' : content_tag(:div,
          builder.check_box("#{name}/NR", :checked => nr_checked, :index => index) +
          builder.label("#{name}/NR", t("NR"), :index => index),
          :class => 'nr')),
      :class => ['tally', error ? 'error' : ''].reject(&:blank?).join(" "))
  end
end
