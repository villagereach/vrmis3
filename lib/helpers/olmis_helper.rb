# -*- coding: utf-8 -*-
# Methods added to this helper will be available to all templates in the application.

module OlmisHelper

  def get_area_from_params(ps = params)
    hierarchy = Olmis.area_hierarchy.map(&:constantize)
    
    area = hierarchy.first.default
    
    hierarchy[1..-1].each do |h|
      if ps[h.param_name].present?
        a = h.find_by_id(ps[h.param_name])
        area = a if a.parent == area
      end
    end
    
    area
  end    
  
  def show_pair(label, text)
    value = (case text
             when String     then text
             when BigDecimal then "%0.2f" % text
             when Date       then I18n.l(text)
             else text.to_s
             end)
    '<dt>' + t(label) + '</dt><dd>' + (value.blank? ? '&nbsp;' : value) + '</dd>'
  end

  def link_pair(label, text, *link)
    '<dt>' + t(label) + '</dt><dd>' + (text.blank? ? '&nbsp;' : (link.compact.empty? ? h(text) : link_to(h(text), *link))) + '</dd>'
  end
  
  def seed_lock_file                                                                 
    "#{RAILS_ROOT}/public/system/seed.lock"                                          
  end                                                                                

  def seed_summary_file
    "#{RAILS_ROOT}/public/system/seed.summary"
  end

  def breadcrumb_string txt
    if txt.respond_to?(:call)
      txt.call(self)
    elsif txt.starts_with?('breadcrumb')
      I18n.t(txt)
    else
      txt
    end
  end
  
  def pct(n, d)
    p = 100.0 * n.to_f / d.to_f
    "%2.2f%%" % (p.nan? ? 0 : p)
  end
  
  def tabs
    {
      'field_coordinator' => [
        ['tab_to_do',             '/'],
        ['tab_before_warehouse_visit', pickup_request_path(@current_user.delivery_zone.maybe.code)],
        #['tab_after_warehouse_visit',  new_pickup_request_path(@current_user.delivery_zone.maybe.code)],
        ['tab_after_warehouse_visit',  pickups_path(@current_user.delivery_zone.maybe.code)],
        ['tab_site_visits',       visits_path],
        ['tab_view_reports',           '/reports'],],
      'admin' => [
        ['tab_fridges',        fridges_path],
        ['tab_health_centers', health_centers_path],
        ['tab_users',          users_path],
        ['tab_reports',        '/reports'],
      ],
      'manager' => [
        ['tab_dashboard',             '/'],
        ['tab_cold_chain', '/cold_chain'],
        ['tab_health_centers', health_centers_path],
        ['tab_fcs', '/fcs'],
        ['tab_reports',           '/reports'],],
      'observer' => [
        ['tab_visits',           '/reports/visited_health_centers'],
        ['tab_coverage',           '/reports/coverage'],
        ['tab_stockouts',           '/reports/stockouts'],
        ['tab_fridge_issues',       '/reports/fridge_issues'],
        ['tab_report_maps',           '/reports/maps'],],
      'provincial_administrator' => [
        ['tab_to_do',             '/'],
        ['tab_manage_cold_chain', '/cold_chain'],
        ['tab_reports',           '/reports'],],
    }
  end

  def current_tab?(path)
    pathv = path.split('/')
    urlv = request.request_uri.split('?').first.split('/')
    if @current_user.maybe.role_id == 1
      return urlv == pathv
    else
      return pathv.second == urlv.second
    end
  end
  
  def role_specific_tabs
    tabs[@current_user.role_code] || []    
  end

  def report_format_for_current_user_role
    @current_user.role.report_format
  end
    
  def session_date
    (Date.parse("#{session[:year]}-#{session[:month]}-01") rescue Date.today.beginning_of_month).strftime("%Y-%m-%d")
  end
  
  def set_date_form(return_to=nil)
    render :partial=>'shared/set_date_form', :locals=>{:return_to=>return_to}
  end
  
  def edit_link_to(*args)
    if @current_user.can_edit?
      link_to(*args)
    end
  end

  def recent_months(count)
    today = Date.today
    returning Array.new do |arr|
      (0..count-1).each do |i|
        arr << (today - i.months).to_date_period
      end
    end
  end  
  
  def country_format_phone(ph, remove_country = true)
    #country-specific, so not localized
    p = ph.to_s
    p.sub!(/^258/,'') if remove_country
    o = ""
    if p[0,1]=="8"
      o = "8 "
      p=p[1,:last]
    else
      o = "n#{p[0]}"
    end
    
    
    %w(23 251 24 281 21 252 293 26 282 271 272 258 26).each do |ac|
      o += "#{ac} "  if p.sub!(/^#{ac}/,'')
    end
    o + "#{p[0,2]} #{p[2,:last]}"
  end
  
  def user_name_and_phone(u)
    return "" if u.nil?
    cphone = country_format_phone(u.phone)
    if cphone.blank? 
      "#{u.name}" 
    else 
      "#{u.name} (#{cphone})"
    end
  end
 
  ## standard epi/visit double-month formatting
  def hcv_month(value, options = {})
    is_epi = options[:is_epi] === true
    format = options[:format] || 'epi_visit_month'
    if value.is_a? String
      visit = Date.from_date_period(value)
    else
      #expects Time or Date
      visit = value.to_date.first_of_month
    end
    if is_epi
      epi = visit
      visit = epi + 1.month
    else
      epi = visit - 1.month
    end

    I18n.t(format, :visit_month => I18n.l(visit, :format => :short_month_of_year),
                   :epi_month   => I18n.l(epi,   :format => :month_abbrev))
  end
    
  ####
  ## css and js.  at some point, we may want to shift to a plugin.  i'm doing this to clean up view code a little
  ####

  def visible_container(id_name, is_visible, tag_name='div', class_name=nil, &block)
    concat(tag(tag_name, 
      {  
        :class => class_name, 
        :id => id_name, 
        :style => is_visible ? '' : 'display: none' 
      }, 
      true))
    yield
    concat('</' + tag_name + '>')
  end
  
  def js_do_with_args(action_args, *css_ids)
    [css_ids].flatten.map{|i| "jQuery('##{i}').#{action_args};"}.join(" ")    
  end

  def js_do(action, *css_ids)
    js_do_with_args("#{action}()", *css_ids)
  end
    
  def js_toggle(*css_ids); js_do(:toggle, css_ids); end
  def js_show(*css_ids); js_do(:show, css_ids); end
  def js_hide(*css_ids); js_do(:hide, css_ids); end
  def js_show_hide(show_ids, hide_ids);  js_show(show_ids)+js_hide(hide_ids); end
    
  def js_set_checked(*css_ids)
    js_do_with_args("attr('checked', true)", css_ids)
  end
    
  def js_highlight_ids(*css_ids)
    content_tag(:script, 
       css_ids.map{|i| "jQuery(document).ready(function(){ jQuery('##{i}').effect('highlight', {}, 3000)});" }.join(" ") 
    )
  end

  def js_show_or_hide_offline_forms_div(id)
    content_tag(:script, 
      "jQuery(document).ready(function(){ if (typeof applicationCache === 'undefined') jQuery('##{id}').hide(); });"
    )
  end

  def jquery_link_to_remote(name, options = {}, html_options = nil)
    # NOTE: Simplified version of PrototypeHelpers#link_to_remote to use jQuery instead.
    # This code only supports options we actually use.
    ajax_options = {}

    url_options = options[:url]
    if url_options.is_a?(Hash)
      # Force :controller to "olmis" and :path to the controller name (otherwise the wrong URL may be generated)
      if url_options[:overwrite_params]
        url_options[:overwrite_params].merge!(:controller => "olmis", :path => controller.controller_path)
      else
        url_options.merge!(:controller => "olmis", :path => controller.controller_path)
      end
      url_options.merge!(:escape => false)
    end

    ajax_options[:url] = "'#{escape_javascript(url_for(url_options))}'"
    ajax_options[:type] = "'#{options[:method].to_s.upcase}'" if options[:type]
    ajax_options[:success] = "function(data, status, xhr){jQuery('##{options[:update]}').replaceWith(data);}" if options[:update]

    function = %Q{ jQuery.ajax({ #{ajax_options.map{|key,value| "#{key.to_s}: #{value}"}.join(",")} }) }

    link_to_function(name, function, html_options || options.delete(:html))
  end

  ####
  #  FC lookups
  ###

  def fcs_to_options(fcs)
    fcs.map{|fc| [fc.name, fc.id]}
  end
  
  def fcs_by_area(area, exclude=nil)
    area.delivery_zones.map(&:field_coordinator).reject{|fc| fc==exclude}
  end
  
  def fc_options_by_delivery_zone(zone, exclude=nil)
    fcs_to_options(zone.users)
  end
     
  ####
  #  Fragement caching
  ####

  def cache_key_prefix_for_fc_month(fc_id, month, locale=session[:locale])    
    "#{locale}-fc-#{fc_id}-#{month}"
  end

  def cache_key_for_fc_month(fc_id, month, suffix)
    cache_key_prefix_for_fc_month(fc_id, month) + "-#{suffix}"    
  end

  def cache_key_prefix_for_hcvisit(hc_id, month, locale=session[:locale])
    "#{locale}-hcvisit-#{hc_id}-#{month}"
  end
  
  def cache_key_for_hcvisit(hc_id, month, suffix)
    cache_key_prefix_for_hcvisit(hc_id, month) + "-#{suffix}"
  end
  
  def expire_caches_for_hc_month(hc, month)
    #expires all fragment caches starting with the prefixes for hcvisit and fc_month
    unless hc.is_a?(HealthCenter)
      hc = HealthCenter.find(hc)
    end
    
    if fc = hc.field_coordinator
      fc = fc.id.to_s
    else
      fc = '-'
    end
    
    controller.expire_fragment(/^..#{cache_key_prefix_for_fc_month(fc, month, nil)}/)
    controller.expire_fragment(/^..#{cache_key_prefix_for_hcvisit( hc.id, month, nil)}/)
  end
  
  def nuke_all_caches
    controller.expire_fragment(/.*/)
  end
  
  ####
  #  jQuery helpers
  ####

  # NOTE: Copies of param_to_jquery and param_from_jquery also live in ActsAsStatTally
  # because the OlmisHelper methods are not accessible there. Do not change these
  # methods without also changing them in ActsAsStatTally.

  # Convert reserved meta characters to safe characters; used when generating data for offline use.
  def param_to_jquery(str)
    str.tr(':,', '%-')
  end

  # Reverse the action of #param_to_jquery; used when parsing data from an offline data submission.
  def param_from_jquery(str)
    str.tr('%-', ':,')
  end
end
