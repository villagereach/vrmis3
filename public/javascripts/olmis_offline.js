var online = true;
var valid_forms = {};
var manifest_files = {
  count:      1,
  downloaded: 0
};
var containers = {
  login:        'login-form',
  admin_home:   'admin-home',
  manager_home: 'manager-home',
  fc_home:      'fc-home',
  fc_actions:   'fc-actions',
  hc:           'hc-selection',
  visit:        'form',
  wh_before:    'warehouse-before',
  wh_after:     'warehouse-after'
};
var roles_screens = {
  fc:      'fc_home',
  manager: 'manager_home',
  admin:   'admin_home'
};
var container_hooks = {
  hide: {},
  show: {},
};
var hash_param_slots = {
  'container': 0,
};
var options = {
  months_to_show: 6,
  autoset_default_visit_date: true
};
var settings = {
  health_center_key_regex: /^\d{4}-\d{2}\/hc\/[^/]+$/,
  warehouse_key_regex:     /^\d{4}-\d{2}\/wh\/[^/]+$/,
  visit_key_regex:         /^\d{4}-\d{2}\/(hc|wh)\/[^/]+$/
};

function get_health_center_key(month, hc) {
  month = month || get_selected_value('visit_date_period');
  hc = hc || get_selected_value('health_center');
  return month + '/hc/' + hc;
}

function get_warehouse_pickup_key(month, dz) {
  month = month || get_selected_value('visit_date_period');
  dz = dz || get_selected_value('delivery_zone');
  return month + '/wh/' + dz;
}

function get_hash_param(param) {
  var values = window.location.hash.replace(/^#/, '').split('/');
  return values[hash_param_slots[param]];
}

function set_hash_param(param, value) {
  var values = window.location.hash.replace(/^#/, '').split('/');
  values[hash_param_slots[param]] = value;
  window.location.hash = values.join('#');
};

container_hooks.show['hc-selection'] = function() {
  setup_visits();
};

container_hooks.show['warehouse-before'] = container_hooks.show['warehouse-after'] = function() {
  reset_pickup_instance(get_warehouse_pickup_key());
};
container_hooks.hide['warehouse-after'] = function() {
  serialize_warehouse_visit();
};

container_hooks.show['form'] = function() {
  reset_olmis_instance(get_health_center_key());
  update_visit_navigation();
  refresh_fridges();
  update_progress_status();  // TODO: Retrieve cached values
};

container_hooks.hide['form'] = function() {
  set_hc_form_status(get_health_center_key(), update_progress_status());
};

function fixup_menu_tabs() {
  $('#tab-menu').removeClass('ui-corner-all ui-widget-content');
  $('#tab-menu .ui-tabs-nav li').removeClass('ui-state-default ui-corner-top');
  $('#tab-menu .ui-tabs-panel').removeClass('ui-corner-bottom');

  // $('#tab-menu a').each(function() {
  //   $(this).focus(function() {
  //     $(this).blur();
  //   });
  // });
}

function update_visit_navigation() {
  // Adjust form container size to be at least as tall as the menu
  var tabs_height = parseInt($("#tab-menu > ul.ui-tabs-nav").css("height"));
  var panel_vpadd = parseInt($("#tab-menu > div.ui-tabs-panel").css("padding-top")) +
                    parseInt($("#tab-menu > div.ui-tabs-panel").css("padding-bottom"));
  $("#tab-menu > div.ui-tabs-panel").css("min-height", (tabs_height - panel_vpadd)+'px');

  // Hide the previous link on the first screen and the next link on the last screen
  var visible_tabs = $("#tab-menu > ul > li:visible");
  var first_screen = visible_tabs.first()[0].id.replace('tab-', 'screen-');
  var last_screen  = visible_tabs.last()[0].id.replace('tab-', 'screen-');
  $("#" + first_screen + " .nav-links a:first").hide();
  $("#" + last_screen + " .nav-links a:last").hide();
}

function go_to_next_screen(this_screen) {
  update_progress_status(this_screen);
  $("#tab-" + this_screen).nextAll().not(".ui-state-disabled").first().find('a').click();
}

function go_to_previous_screen(this_screen) {
  update_progress_status(this_screen);
  $("#tab-" + this_screen).prevAll().not(".ui-state-disabled").first().find('a').click();
}

function set_equipment_notes_area_size() {
  var ta = $('#screen-equipment_status textarea');
  ta.height(ta.parents('td').attr('rowspan') * ta.parents('td').prev().height() * 0.7);
}

function do_download() {
  manifest_files['downloaded'] = 0;
  manifest_files['count'] = jQuery.
    ajax({ type:     'GET',
           url:      document.childNodes[1].getAttribute('manifest').split('?')[0],
           data:     { locale: I18n.locale },
           dataType: 'text',
           async:    false
         }).
    responseText.
    replace(/^[\s\S]*CACHE:([\s\S]*)/, "$1").
    replace(/^([\s\S]*)^[A-Z]+:[\s\S]*/m, "$1").
    split("\n").
    filter(function(s) { return !(s.match(/^#/) || s.match(/^\s*$/)) }).
    length;

  go_online();
}

function do_progress() {
  if (manifest_files['downloaded']++ === 0) {
    jQuery('#status_indicator').removeClass('updated');
    jQuery('#download_indicator').addClass('active');
  }
  go_online();

  var progress = manifest_files['downloaded'] / manifest_files['count'];
  var width = jQuery('#download_indicator').innerWidth();
  // In case the manifest file count is wrong, don't allow the progress indicator to show > 100%
  jQuery('#download-progress-bar').width(Math.min((width * progress).toFixed(), width) + "px");
  jQuery('#download-pct').text(Math.min((100 * progress).toFixed(), 100) + "%");
}

function do_update() {
  jQuery('#download_indicator').removeClass('active');
  go_online();

  try {
    applicationCache.swapCache();
  }
  catch (e) {
    DebugConsole.write("applicationCache.swapCache failed: " + e);
    return;
  }
  jQuery('#status_indicator').addClass('updated');
}

function do_cached() {
  jQuery('#download_indicator').removeClass('active');
}

function go_online() {
  online = true;
  jQuery("#online_indicator").addClass("online").removeClass("offline");
  show_or_hide_upload_link();
}

function go_offline() {
  online = false;
  jQuery("#online_indicator").addClass("offline").removeClass("online");
  jQuery("#upload_link").addClass("offline").removeClass("online");
}

function check_update_status() {
  if (navigator.onLine) {
    try {
      applicationCache.update();
    }
    catch (e) {
      DebugConsole.write("applicationCache.update failed: " + e);
    }
  }
}

function action_not_implemented() {
  alert("Action not yet implemented");
}

function set_active_tab(tab) {
  jQuery('.menu-tab').removeClass('selected-tab');
  jQuery('.menu-tab[id="tab-'+tab+'"]').addClass('selected-tab');
}

function get_available_visit_date_periods() {
  var now = new Date();
  var month = now.getMonth();
  var year = now.getFullYear();
  var months = [];

  for (var i = 0; i < options['months_to_show']; i++) {
    var y = year;
    var m = month - i;
    if (m < 0) {
      y--;
      m += 12;
    }
    var month_current = (y == year && m == month);
    var month_value = y + '-' + ('0' + (m+1)).substr(-2,2);
    var month_text;
    try {
      month_text = I18n.l(Date.from_date_period(month_value), { format: 'month_of_year' });
    } catch(e) {
      month_text = '';
    }

    months.push([month_value, month_text, month_current]);
  }

  return months;
}

function setup_visit_date_periods() {
  xforms.openAction();

  var month_selector = jQuery('#visit-month-selector');
  var select_control = month_selector.find('select');
  select_control.empty();

  var months = get_available_visit_date_periods();
  for (var i = 0, l = months.length; i < l; i++) {
    var month_value = months[i][0];
    var month_text  = months[i][1];
    var is_current_month  = months[i][2];

    var opt = jQuery(document.createElement('option'));
    opt.attr('text', month_text);
    opt.attr('value', month_value);
    // FIXME: Set the default selection. Neither of the following methods work. Why?
    // NOTE: This isn't terribly important as long as the current month is the first one in the list.
    //opt.attr('selected', is_current_month);
    //if (is_current_month) opt.attr('selected', 'selected');
    select_control.append(opt);
 }                    

  xforms.closeAction();
}

function set_selected_value(name, value) {
  $(selected_values).attr(name, value.toString());
}

function get_selected_value(name) {
  return selected_values[name] || ''
}

function find_province_district_health_center(hc) {
  var health_center = find_health_center_by_code(hc);
  var dz            = health_center.delivery_zone;
  var district      = data_instance.areas_by_area_code[health_center.area_code];
  var province      = district ? data_instance.areas_by_area_code[district.parent_code] : null;

  return [province.name, district.name, hc, dz, get_selected_value('field_coordinator')];
}

function find_health_centers_in_delivery_zone(dz) {
  return find_health_centers_by_attr('delivery_zone', dz);
}

function find_health_center_by_code(code) {
  return find_health_centers_by_attr('code', code)[0];
}

function find_health_centers_by_attr(attr, value) {
  return $(data_instance.health_centers).filter(function(i) { return this[attr] == value; });
}

function get_fridge_codes_for_health_center() {
  return find_health_center_by_code(get_selected_value('health_center'))['fridge_codes'];
}

function select_visit() {
  var key = $('#saved-forms-control').val();
  if (key && key.match(settings.health_center_key_regex)) {
    setTimeout(function() {
      set_selected_value('health_center', key.split('/')[2]);
      show_container(containers['visit']);
    }, 1);
  }
}

function reset_pickup_instance(key) {
  var instance = localStorage.getItem(key);
  if (instance) {
    pickup_instance = JSON.parse(instance);
  } else {
    pickup_instance = generate_pickup_instance();
    var ideal_stock = data_instance.warehouse_ideal_stock[get_selected_value('delivery_zone')];
    for (var x in ideal_stock) {
      try {
        if (pickup_instance[x]) pickup_instance[x].DeliveryRequest = ideal_stock[x];
      } catch(e) {
        if (console) console.exception(e);
      }
    }
  }
  reset_pickup_bindings();
}

function reset_olmis_instance(key) {
  var instance = localStorage.getItem(key);
  if (instance)
    olmis_instance = JSON.parse(instance);
  else {
    olmis_instance = generate_olmis_instance();
    var fridge_codes = get_fridge_codes_for_health_center();
    if (fridge_codes.length > 0) {
      for (var i = 0, l = fridge_codes.length; i < l; i++) {
        new_fridge(fridge_codes[i]);
      }
    } else {
      // There must be at least one fridge, even if it's blank
      new_fridge();
    }
  }
  reset_olmis_bindings();
}

function show_warehouse(type) {
  show_container(containers['wh_'+type]);
}

function show_container( container ) {
  var visible = $('body > .container:visible').attr('id')

  if (container_hooks.hide[visible])
    container_hooks.hide[visible].call()

  jQuery('body > .container').hide();
  jQuery('body > #'+container).show();
  
  if (container_hooks.show[container])
    container_hooks.show[container].call()
  
  set_hash_param('container', container)
}

function login() {
  // NOTE: Only checking for a valid role
  var landing_page = roles_screens[get_selected_value('access_code')];
  if (landing_page) {
    set_selected_value('logged_in', true)
    show_main_page(landing_page);
  } else {
    $('#access_code').val('');
    alert(I18n.t('data_sources.hcvisit.login.invalid'));
  }
}

function logout() {
  set_selected_value('access_code', '');
  set_selected_value('logged_in',   '');
  show_container(containers['login']);
  autofocus();
}

function set_context() {
  var today = Date.today();
  var date = Date.from_date_period(get_selected_value('visit_date_period'));

  if (options['autoset_default_visit_date']) {
    var default_visit_date = date.getMonth() == today.getMonth() ? today : date.beginning_of_month();
    set_selected_value('default_visit_date', default_visit_date.format('%Y-%m-%d'));
  }

  set_selected_value('visit_period_selected', true);
  show_container(containers['fc_actions']);
}

function select_location() {
  //populate_warehouse_pickups();
  show_visits();
}

function show_visits() {
  show_container(containers['hc']);
  $('input.hasDatepicker').each(function(i, e) {
    $(e).datepicker('destroy');
  });
}

function show_main_page(landing_page) {
  var code = get_selected_value('access_code');
  if (!landing_page) {
    // For a FC, return to the fc-actions page if a visit period has already been selected,
    // e.g., the user is on the HC selection page or a visit or warehouse pickup form.
    if (code == 'fc' && get_selected_value('visit_period_selected')) {
      landing_page = 'fc_actions';
    } else {
      landing_page = roles_screens[code];
    }
  }

  if (landing_page != 'fc_actions') {
    set_selected_value('visit_period_selected', false);
  }
  set_selected_value('health_center', '');
  show_or_hide_upload_link();
  show_container(containers[landing_page]);
}

function show_or_hide_upload_link() {
  if (has_forms_ready_for_upload()) {
    $("#upload_link").addClass("online").removeClass("offline");
  } else {
    $("#upload_link").removeClass("online").addClass("offline");
  }
}

function has_forms_ready_for_upload() {
  var ready = false;
  for (var key in valid_forms) {
    ready = key.match(settings.visit_key_regex) && valid_forms[key];
    if (ready) break;
  }
  return ready;
}

function get_context_path_value(ctx, path) {
  //TODO: Implement XPath
  var doc = [ ctx.xfElement.doc ];
  var nodes = path.split('/');
  nodes.unshift(ctx.id);
  nodes.filter(function(p) { return p != '' }).forEach(function(p, i) {
    newdoc = []
    doc.forEach(function(n, ni) {
      newdoc = newdoc.concat(n.childNodes.filter(function(c) { return c.nodeName == p; }));
    });
    doc = newdoc
  })
  return doc;
}
          
function update_visit_history(obj) {
  // this data is to support the offline autoeval report, please see offline_autoeval.js.erb 
  
  var health_center = get_selected_value('health_center');
  var date_period   = get_selected_value('visit_date_period');
  var history = JSON.parse(localStorage[health_center + '/visit-history'] || '{}');
  
  if (!history[date_period])
    history[date_period] = {};
  
  for (key in obj)
    history[date_period][key] = obj[key];

  localStorage[health_center + '/visit-history'] = JSON.stringify(history);
}

function inventory_quantities(type) {
  return get_context_path_value($('olmis'), '/inventory/item').
    filter(function(e) { return e.getAttributeNS(null, 'type') == type; }).
    filter(function(e) { return AutoevalData.trackable_package_codes.indexOf(e.getAttributeNS(null, 'for')) >= 0; }).  
    filter(function(e) { nr = e.getAttributeNS(null, 'nr'); return !nr || nr == '' || nr == 'false'; }).
    map(   function(e) { q = e.getAttributeNS(null, 'qty'); return q ? [e.getAttributeNS(null, 'for'), q] : null; });
}

function update_stockouts() {
  var e = inventory_quantities('ExistingHealthCenterInventory');
  var d = inventory_quantities('DeliveredHealthCenterInventory');
  
  update_visit_history({ 'existing': e, 'delivered': d });
}

var save_timeouts = {};

function get_hc_form_status(visit_key) {
  var status = 'unknown';
  if (valid_forms[visit_key] === true) {
    status = 'valid';
  } else if (valid_forms[visit_key] === false) {
    status = 'incomplete';
  } else if (typeof valid_forms[visit_key] == 'string') {
    status = valid_forms[visit_key];
  }
  return status;
}

function set_hc_form_status(key, status) {
  valid_forms[key] = status;
}

function setup_form_options(local_forms, only_set_monthly_status) {
  var savedVisits = jQuery('#saved-forms-control');
  if (!only_set_monthly_status) savedVisits.empty();
    
  var districts = [];
  for (var district in local_forms) {
    districts.push(district);
  }
  districts.sort();

  var month = null;
  var statuses = [];
  var si = 0;

  for (var di = 0, dl = districts.length; di < dl; di++) {
    var district = districts[di];
    var optgroup;
    if (!only_set_monthly_status) {
      optgroup = jQuery(document.createElement('optgroup'));
      optgroup.attr('label', data_instance.areas_by_area_code[district].name);
    }

    var keys = local_forms[district].sort();
    for (var hci = 0, hcl = keys.length; hci < hcl; hci++, si++) {
      visit_key = get_health_center_key(keys[hci][0], keys[hci][1]);
      var status = get_hc_form_status(visit_key);
      statuses.push(status);
      if (!month) month = keys[hci][0];

      if (!only_set_monthly_status) {
        var opt = jQuery(document.createElement('option'));
        opt.attr('text', keys[hci][2]);
        opt.attr('value', visit_key);

        opt.addClass(status);
        if (status == 'accept') {
          opt.attr('disabled', true);
        }
        optgroup.append(opt);
      }
    }
    savedVisits.append(optgroup);
  }
}

function uniq(arr) {
  var ret = [], found = {};
  for (var i = 0, l = arr.length; i < l; i++) {
    if (!found[arr[i]]) {
      found[arr[i]] = true;
      ret.push(arr[i]);
    }
  }
  return ret;
}

function setup_visits() {
  var hcs = find_health_centers_in_delivery_zone(get_selected_value('delivery_zone'));
  var months = get_available_visit_date_periods();
  var month_period = get_selected_value('visit_date_period');

  localStorage['valid forms'] = JSON.stringify(valid_forms); 

  for (var i = 0, l = months.length; i < l; i++) {
    var month = months[i][0];
    var local_forms = {};
    for (var hci = 0, hcl = hcs.length; hci < hcl; hci++) {
      var name = hcs[hci].name;
      var code = hcs[hci].code;
      
      var key = [month, code, name];

      // TODO: Separate HC and WH forms
      if (local_forms[hcs[hci].area_code] === undefined)
        local_forms[hcs[hci].area_code] = []
      
      local_forms[hcs[hci].area_code].push(key);
    }

    setup_form_options(local_forms, month_period != month);
  }
}

function reset_saved_forms_search() {
  jQuery('#saved-forms-control optgroup, #saved-forms-control option').each(function() {
    jQuery(this).removeClass('hidden');
  });
  jQuery('#saved-forms-filter').val('');
}

function setup_visit_search() {
  reset_saved_forms_search();
  jQuery('#saved-forms-filter').keyup(function() {
    // case-insensitive match from beginning of health center name
    var re = new RegExp("^"+jQuery(this).val(), "i");
    // hide options that don't match
    jQuery('#saved-forms-control option').each(function() {
      if (re.test(this.text)) {
        jQuery(this).removeClass('hidden');
      } else {
        jQuery(this).addClass('hidden');
      }
    });
    // hide any optgroups that have no visible options
    jQuery('#saved-forms-control optgroup').each(function() {
      if (jQuery(this).find(':not(.hidden)').length == 0) {
        jQuery(this).addClass('hidden');
      } else {
        jQuery(this).removeClass('hidden');
      }
    });
  });
}

function possiblyEvaluatableValue(val, def) {
  if (val.evaluate) {
    var v = val.evaluate();
    if (v) {
      if (typeof v == 'string') {
        return v;
      } else {
        // TODO: Not sure how we get here. When using older version of XSLTForms?
        var n = v[0];
        if (n) {
          return (typeof n == 'string' ? n : getValue(n));
        }
      }
    }
  } else {
    return val;
  }
  return def;
}

function radioValueFn(val) {
  return function(ev) {
    return((ev == val) ? 'checked' : false);
  };
}

function fridgeProblemsGetFn(val) {
  return function(newValue, settings) {
    return newValue.indexOf(val) < 0 ? false : 'checked';
  };
}

function fridgeProblemsSetFn(val) {
  return function(newValue, settings) {
    var problems = settings.target.problem;
    var i = problems.indexOf(val);
    if (newValue && i < 0) {
      problems.push(val);
    } else if (!newValue && i >= 0) {
      problems.splice(i, 1);
    }
    return problems;
  };
}

function olmis_localize_date(value) {
  try {
    if (value && value.match(/^\d{4}-\d{2}-\d{2}$/)) {
      return Date.parseExact(value, 'yyyy-MM-dd').format(I18n.t('date.formats.default'));
    }
  } catch (e) { }
  return '';
}

function olmis_delocalize_date(value) {
  if(value) { 
    try {
      return Date.parse(value).toString('yyyy-MM-dd');
    } catch(e) { }
  }
  return '';
}

function olmis_localize_yearmonth(value) {
  if (value) {
    var m;
    if (m = value.match(/^(\d{4})-(\d{2})-\d{2}$/)) {
      return m[2] + '/' + m[1];
    }
  }
  return '';
}

function olmis_delocalize_yearmonth(value) {
  if (value) {
    var m;
    if (m = value.match(/^(0[1-9]|1[0-2])\/(\d{4})$/)) {
      return m[2] + '-' + m[1] + '-01';
    }
  }
  return '';
}

function setup_saved_visits() {
  var local_forms = [];

  forEachLocalStorageKey(function(key) {
    if (key.match(settings.health_center_key_regex) && valid_forms[key]) {
      local_forms.push('<li id="' + key.replace('/','_') + '" class="status ' + (valid_forms[key] ? 'complete' : 'todo') + '"><span>' + get_hc_visit_label_for(key) + '</span></li>');
    }
  });

  jQuery('#upload-ready ul').html(local_forms.join('')) 
  if (jQuery('#upload-ready ul li.complete').length > 0) {
    jQuery('#upload-empty').hide();
    jQuery('#upload-button').show();
  } else {
    jQuery('#upload-button').hide();
    jQuery('#upload-empty').show();
  }
}

function forEachLocalStorageKey(f) {
  if (localStorage[0]) {
    for (var i = 0, l = localStorage.length; i < l; i++)  {
      f(localStorage[i]);
    }
  } else {
    for (var x in localStorage) {
      f(x);
    }
  }
}

function upload(node, do_sync) {
  var key = node.id.replace('_','/');
  var item = jQuery(node);
  var ready_list = jQuery('#upload-ready ul');
  var uploaded_list = jQuery('#upload-uploaded ul');
  var upload_button = jQuery('#upload-button').find('input');
  upload_button.attr('disabled', true);
  item.addClass('working');
  $.ajax( { 
      async: do_sync,
      contentType: 'application/json',
      data: localStorage[key],
      url: '/visits/' + key + '.json',
      dataType: 'html',
      type: 'PUT',
      error: function (XMLHttpRequest, textStatus, errorThrown) {      
        set_hc_form_status(key, 'reject');
        alert(textStatus);
      },
      success: function(data, textStatus, xhr) {
        set_hc_form_status(key, 'accept');
        localStorage.removeItem(key);
        uploaded_list.append(item);
        if (ready_list.children().length == 0) upload_button.parent().hide();
      },
      complete: function(xhr, textStatus) {
        item.removeClass('working');
        upload_button.attr('disabled', false);
      }
  } );
}

function get_hc_visit_label_for(key) {
  var v = key.split('/');
  return find_health_center_by_code(v[2]).name + ', ' + I18n.l(Date.from_date_period(v[0]), { format: 'month_of_year'});
}

function upload_all() {
  $('#upload-ready li.complete').each(function(i,n) { upload(n, false) });
}

function is_logged_in() {
  $('#fc-action-links a[href="#upload"]').click();
}

function check_logged_in() {
  $('#login-login').focus();
  $.ajax( { 
      async: true,
      url: '/logged-in?',
      type: 'GET',
      success: function(data, textStatus, xhr) {  
        is_logged_in();
      }
  } );
}

function ajax_login() {
  $('#login-button').attr('disabled', true);
  $.ajax( { 
      async: true,
      data: { 'login[username]': $('#login-login').attr('value'), 'login[password]': $('#login-password').attr('value') },
      url: '/login',
      dataType: 'html',
      type: 'POST',
      error: function (XMLHttpRequest, textStatus, errorThrown) {      
      },
      success: function(data, textStatus, xhr) {  
        is_logged_in();
      },
      complete: function(xhr, textStatus) {
        $('#login-button').attr('disabled', false);
      }
  } );
}

function finish_upload() {
  setup_visits();
  $('#upload-uploaded ul').empty();
}

function _serialize_instance_for(key, instance) 
{
  var re1 = new RegExp(',"jQuery\\d+":\\d+', 'g');
  var re2 = new RegExp('{"jQuery\\d+":\\d+,', 'g');
  localStorage[key] = JSON.stringify(instance).replace(re1, '').replace(re2, '{');
}

function serialize_visit() {
  _serialize_instance_for(get_health_center_key(), olmis_instance);
}

function serialize_warehouse_visit() {
  _serialize_instance_for(get_warehouse_pickup_key(), pickup_instance);
}

var selected_values = {};

$(function() {
  $('#saved-forms-control').change(select_visit);
  
  try {
    valid_forms = JSON.parse(localStorage['valid forms']) || {};
  } catch(e) {
    valid_forms = {};
  }
  
  for (var i = 0, l = sessionStorage.length; i < l; i++) {
    $(selected_values).attr(sessionStorage[i], sessionStorage[sessionStorage[i]]);
  }

  $(selected_values).attrChange(function(ev) {
      sessionStorage[ev.attrName] = ev.newValue;
  });
  
  if (get_selected_value('logged_in') == "true") {
    var screen = get_hash_param('container');

    if (screen)
      show_container(screen);
    else
      show_main_page();
  }
  else    
    show_container(containers['login']);
  
  setup_visit_search();
  fixup_menu_tabs();

  /*
  window.setInterval(check_update_status, 3 * 1000);
  
  var statuses = ['cached', 'checking', 'downloading', 'error', 'noupdate', 'obsolete', 'progress', 'updateready'];

  applicationCache.addEventListener('error',       go_offline,  true);
  applicationCache.addEventListener('noupdate',    go_online,   true);
  applicationCache.addEventListener('downloading', do_download, true);
  applicationCache.addEventListener('progress',    do_progress, true);
  applicationCache.addEventListener('updateready', do_update,   true);
  applicationCache.addEventListener('cached',      do_cached,   true);

  go_offline();
  */
  $('#fc-action-links a[href="#login"]').fancybox( 
    { 'hideOnContentClick': false,
      'autoScale': false,
      'autoDimension': true,
      'onComplete': check_logged_in });
  $('#fc-action-links a[href="#upload"]').fancybox( 
    { 'hideOnContentClick': false,
      'autoScale': false,
      'autoDimension': true,
      'onComplete': setup_saved_visits,
      'onClosed': finish_upload });
});

function add_screen_sequence_tags() {
  $("#tab-menu div.ui-tabs-panel span.seqno").each(function(i,e) { $(e).html(i+1); });
}

function update_progress_status(tabs) {
  var valid = true;

  // TODO: Refactor and cache validation results

  if (tabs) {
    tabs = $.makeArray(tabs);
    for (var i = 0, l = tabs.length; i < l; i++) {
      var e = typeof tabs[i] == "number" ? $('#tab-menu > ul > li')[tabs[i]] : $('#tab-'+tabs[i]);
      var link = $(e).find('a');
      link.removeClass("complete incomplete todo");

      if (!$(e).hasClass('ui-state-disabled')) {
        var div = $($('a', $(e)).attr('href'));
        var inputs = $('*:input.enabled', div);
        if (inputs.length > 0 && inputs.valid()) {
          link.addClass("complete");
        } else {
          valid = false;
          link.addClass("todo");
        }
      }
    }
  } else {
    $('#tab-menu > ul > li').each(function(i,e) {
      var link = $(e).find('a');
      link.removeClass("complete incomplete todo");

      if (!$(e).hasClass('ui-state-disabled')) {
        var div = $($('a', $(e)).attr('href'));
        var inputs = $('*:input.enabled', div);
        if (inputs.length > 0 && inputs.valid()) {
          link.addClass("complete");
        } else {
          valid = false;
          link.addClass("todo");
        }
      }
   });
  }

  return valid;
}

function preinitialize_visit() {
  // Run actions that must be performed *after* visit form is reset but
  // *before* health center bindings are installed

  $('#visit-form *:input').addClass('enabled');
  
  $('#visit-form').setupValidation();

  $('#tab-menu').tabs({
    show: function(event, ui) {
      var current_screen = get_selected_value('current_screen');
      update_progress_status(current_screen.substr(7));
      set_selected_value('current_screen', ui.panel.id);
      if (ui.panel.id == 'screen-equipment_status') {
        set_equipment_notes_area_size();
      }
    }
  });
  add_screen_sequence_tags();
}

function initialize_visit() {
  // Run actions that must be performed *after* health center bindings are 
  // installed
  
  $('#visit-form').addFormGridEvents();

  $('#visit-form *:input').blur(serialize_visit);
  $('#visit-form').setup_selected_values();
  
  $('#visit-form').init_expression_fields();
  
  $('div.datepicker').each(function(i, e) {
    var dp = setup_datepicker($('input[type="text"]', $(e))[0],
                              {
                                onSelect: function(dateText, inst) { $(this).valid(); }
                              });
    if (dp.attr('id') == 'visited_at') {
      var date = Date.from_date_period(get_selected_value('visit_date_period'));
      dp.datepicker('option', 'minDate', date.beginning_of_month());
      dp.datepicker('option', 'maxDate', new Date(Math.min(date.end_of_month(), Date.today())));
    }
  });

  // Link NR checkboxes to their associated input fields so that checking a NR checkbox clears the
  // associated input field, and entering a value in an input field clears the associated NR checkbox.
  $('input[required_unless_nr]', $('#visit-form')).each(function(i, e) {
    var nr = $('#'+$(e).attr('required_unless_nr'), $(e).parent())
    nr.change(function() {
      if ($(this).attr('checked')) {
        $(e).val('');
        $(e).change();
      }
      $(e).valid();
    });
    
    $(e).change(function() { 
      if ($(this).val().length > 0) {
        var nr = $('#'+$(this).attr('required_unless_nr'), $(this.parentNode));
        nr.attr('checked', false);
      }
    });
  });

  // Show the first (visit) screen rather than the last screen viewed, possibly
  // for a different health center. However, the screen's validations are not
  // run unless another screen is selected first (so select the last screen before
  // selecting the first screen).
  $('#tab-menu').tabs('select', $('#tab-menu').tabs('length')-1);
  $('#tab-menu').tabs('select', 0);
}

function preinitialize_pickup() {
  // Run actions that must be performed *after* warehouse pickup form is reset but
  // *before* warehouse pickup bindings are installed
  
  $('#warehouse_visit-form *:input').addClass('enabled');
  $('#warehouse_visit-form').setupValidation();
}

function initialize_pickup() {
  // Run actions that must be performed *after* warehouse pickup bindings are 
  // installed

  $('#warehouse_visit-form *:input').blur(serialize_warehouse_visit);

  $('#warehouse_visit-form *:input.enabled').valid();

  $('div.datepicker').each(function(i, e) {
    var date = Date.from_date_period(get_selected_value('visit_date_period'));
    setup_datepicker($('input[type="text"]', $(e))[0],
                     {
                       onSelect: function(dateText, inst) { $(this).valid(); },
                       minDate:  date.beginning_of_month(),
                       maxDate:  new Date(Math.min(date.end_of_month(), Date.today()))
                     });
  });
}
