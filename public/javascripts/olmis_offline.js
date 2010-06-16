var online = true;
var valid_forms = {};
var manifest_files = {
  count:      1,
  downloaded: 0
};
var selected_values = {};
var containers = {
  login:        'login-form',
  admin_home:   'admin-home',
  manager_home: 'manager-home',
  fc_home:      'fc-home',
  fc_actions:   'fc-actions',
  hc:           'hc-selection',
  visit:        'form',
  upload:       'upload-home',
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
  show: {}
};
var hash_param_slots = {
  container: 0
};
var options = {
  months_to_show:             6,
  autoset_default_visit_date: true,
  user_initiated_update:      false,
  health_center_key_regex:    /^\d{4}-\d{2}\/hc\/[^/]+$/,
  warehouse_key_regex:        /^\d{4}-\d{2}\/wh\/[^/]+$/,
  visit_key_regex:            /^\d{4}-\d{2}\/(hc|wh)\/[^/]+$/,
  update_check_interval:      0,
  ping_timeout:               5000
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
  window.location.hash = '#'+values.join('/');
};

container_hooks.show['fc-actions'] = function () {
  set_after_warehouse_link_status();
};

container_hooks.show['hc-selection'] = function() {
  setup_visits();
};

container_hooks.show['warehouse-before'] = container_hooks.show['warehouse-after'] = function() {
  reset_pickup_instance(get_warehouse_pickup_key());
};
container_hooks.hide['warehouse-before'] = function() {
  $('#warehouse_visit-form div.datepicker input').datepicker('destroy');
};
container_hooks.hide['warehouse-after'] = function() {
  $('#warehouse_visit-form div.datepicker input').datepicker('destroy');
};

container_hooks.show['form'] = function() {
  reset_olmis_instance(get_health_center_key());
  update_visit_navigation();
  refresh_fridges();
  update_values_for_calculations();
  $('#visit-form').init_expression_fields();
  update_progress_status();  // TODO: Retrieve cached values
};

container_hooks.hide['form'] = function() {
  set_hc_form_status(get_health_center_key(), update_progress_status());
  $('#visit-form div.datepicker input').datepicker('destroy');
};

container_hooks.show['upload-home'] = function() {
  update_upload_links();
};

function fixup_menu_tabs() {
  $('#tab-menu').removeClass('ui-corner-all ui-widget-content');
  $('#tab-menu .ui-tabs-nav li').removeClass('ui-state-default ui-corner-top');
  $('#tab-menu .ui-tabs-panel').removeClass('ui-corner-bottom');
}

function update_values_for_calculations() {
  $('#health_center_catchment_population').val(get_population_for_health_center());
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

function do_error() {
  if (options.user_initiated_update) {
    options.user_initiated_update = false;
    $('#update_status span').hide();
    $('#update_status_error-indicator').show();
  }
  go_offline();
}

function do_noupdate() {
  if (options.user_initiated_update) {
    options.user_initiated_update = false;
    $('#update_status span').hide();
    $('#update_status_no_update-indicator').show().delay(5000).fadeOut(1000);
  }
  go_online();
}

function do_download() {
  manifest_files.downloaded = 0;
  manifest_files.count = $.
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
  if (manifest_files.downloaded++ === 0) {
    if (options.user_initiated_update) {
      $('#update_status span').hide();
      $('#update_status_download-indicator').show();
    } else {
      $('#status_indicator').removeClass('updated');
      $('#download_indicator').addClass('active');
    }
  }
  go_online();

  if (!options.user_initiated_update) {
    var progress = manifest_files.downloaded / manifest_files.count;
    var width = $('#download_indicator').innerWidth();
    // In case the manifest file count is wrong, don't allow the progress indicator to show > 100%
    $('#download-progress-bar').width(Math.min((width * progress).toFixed(), width) + "px");
    $('#download-pct').text(Math.min((100 * progress).toFixed(), 100) + "%");
  }
}

function update_offline_data() {
  options.user_initiated_update = true;
  $('#update_status span').hide();
  $('#update_status_check-indicator').show();
  check_update_status();
}

function do_update() {
  if (options.user_initiated_update) {
    $('#update_status span').hide();
  } else {
    $('#download_indicator').removeClass('active');
  }
  go_online();

  try {
    applicationCache.swapCache();
  }
  catch (e) {
    if (console) console.log("applicationCache.swapCache failed: " + e);
    return;
  }

  if (options.user_initiated_update) {
    $('#update_status_update-indicator').show();
    // Remove the link
    var link = $('#update_status').prev();
    link.replaceWith('<span>'+link.html()+'</span>');
  } else {
    $('#status_indicator').addClass('updated');
  }
}

function do_cached() {
  // TODO: Why are these needed? Should have already been handled in do_update()
  if (options.user_initiated_update) {
    $('#update_status span').hide();
  } else {
    $('#download_indicator').removeClass('active');
  }
}

function go_online() {
  online = true;
  //$("#online_indicator").addClass("online").removeClass("offline");
  update_upload_links();
}

function go_offline() {
  online = false;
  //$("#online_indicator").addClass("offline").removeClass("online");
  update_upload_links();
}

function check_online(e) {
  var spinner = e ? $(e).next(".loading-indicator") : null;
  $.ajax({ async: true,
           type: 'GET',
           url: '/ping',
           dataType: 'text',
           timeout: options.ping_timeout,
           success: function(data, textStatus, xhr) {
             go_online();
           },
           error: function(xhr, textStatus, errorThrown) {
             go_offline();
           },
           beforeSend: function(xhr, textStatus) {
             if (spinner) spinner.css("visibility", "visible");
           },
           complete: function(xhr, textStatus) {
             if (spinner) spinner.css("visibility", "hidden");
           }
         });
}

function check_update_status() {
  if (navigator.onLine) {
    try {
      applicationCache.update();
    }
    catch (e) {
      if (console) console.log("applicationCache.update failed: " + e);
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

  for (var i = 0; i < options.months_to_show; i++) {
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

function set_selected_value(name, value) {
  $(selected_values).attr(name, value);
}

function get_selected_value(name) {
  var value = selected_values[name];
  return value !== undefined ? value : ''
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

function find_warehouse_by_code(code) {
  return find_delivery_zones_by_attr('code', code)[0];
}

function find_delivery_zones_by_attr(attr, value) {
  return $(data_instance.delivery_zones).filter(function(i) { return this[attr] == value; });
}

function get_fridge_codes_for_health_center() {
  return find_health_center_by_code(get_selected_value('health_center'))['fridge_codes'];
}

function get_ideal_stock_for_health_center() {
  return find_health_center_by_code(get_selected_value('health_center'))['ideal_stock'];
}

function get_population_for_health_center() {
  return find_health_center_by_code(get_selected_value('health_center'))['population'];
}

function show_loading(fn) {
  var panel = $('#loading-panel');
  panel.
    css('top', ($(window).height() - panel.outerHeight())/2 + window.pageYOffset).
    css('left', ($(window).width() - panel.outerWidth())/2 + window.pageXOffset).
    fadeIn('slow', function() {
      fn();
      panel.fadeOut('slow');
    });
}

function select_visit() {
  var key = $('#saved-forms-control').val();
  if (key && key.match(options.health_center_key_regex)) {
    show_loading(function() {
      set_selected_value('health_center', key.split('/')[2]);
      show_container(containers.visit);
    });
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
        if (pickup_instance['DeliveryRequest'][x] !== undefined) pickup_instance['DeliveryRequest'][x] = ideal_stock[x];
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

function show_upload_page() {
  show_container(containers.upload);
}

function show_container(container) {
  var visible = $('body > .container:visible').attr('id')

  if (container_hooks.hide[visible])
    container_hooks.hide[visible].call();

  $('body > .container').hide();
  $('body > #'+container).show();
  
  if (container_hooks.show[container])
    container_hooks.show[container].call();

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
  var action = function() {
    set_selected_value('access_code', '');
    set_selected_value('delivery_zone', '');
    set_selected_value('health_center', '');
    set_selected_value('logged_in', false);
    set_selected_value('visit_date_period', '');
    set_selected_value('visit_period_selected', false);
    show_container(containers.login);
    autofocus();
  };
  if (hcvisit_screen_is_active()) {
    show_loading(function() {
      action();
    });
  } else {
    action();
  }
}

function hcvisit_screen_is_active() {
  return get_hash_param('container') == containers.visit;
}

function set_context() {
  var today = Date.today();
  var date = Date.from_date_period(get_selected_value('visit_date_period'));

  if (options.autoset_default_visit_date) {
    var default_visit_date = date.getMonth() == today.getMonth() ? today : date.beginning_of_month();
    set_selected_value('default_visit_date', default_visit_date.format('%Y-%m-%d'));
  }

  set_selected_value('visit_period_selected', true);
  set_after_warehouse_link_status();
  show_container(containers.fc_actions);
}

function select_location() {
  show_visits();
}

function show_visits() {
  var action = function() {
    show_container(containers.hc);
    $('input.hasDatepicker').each(function(i, e) {
      $(e).datepicker('destroy');
    });
  };
  if (hcvisit_screen_is_active()) {
    show_loading(function() {
      action();
    });
  } else {
    action();
  }
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

  var action = function() {
    show_container(containers[landing_page]);
    set_selected_value('health_center', '');  // Must be after container change
  };

  if (hcvisit_screen_is_active()) {
    show_loading(function() {
      action();
    });
  } else {
    action();
  }
}

function update_upload_links() {
  var now = new Date();
  var status = online ? "online" : "offline";
  $("#upload_status .status").removeClass("online offline");
  if (online) {
    $("#upload-links .offline").hide();
    $("#upload-links .online").show();
  } else {
    $("#upload-links .online").hide();
    $("#upload-links .offline").show();
  }
  $("#upload_status .status").
    addClass(status).
    html(I18n.t("data_sources.hcvisit.upload_main.status."+status,
                { time: I18n.l(now, { time: true, format: "long" }) } ));
  if (has_forms_ready_for_upload()) {
    $("#forms_to_upload").html(I18n.t("data_sources.hcvisit.upload_main.forms_to_upload",
                                      { count: num_forms_ready_for_upload() }));
    $("#upload-links .not_ready").hide();
    $("#upload-links .ready").show();
  } else {
    $("#forms_to_upload").html(I18n.t("data_sources.hcvisit.upload_main.no_forms_to_upload"));
    $("#upload-links .ready").hide();
    $("#upload-links .not_ready").show();
  }
}

function has_forms_ready_for_upload() {
  var ready = false;
  for (var key in valid_forms) {
    ready = key.match(options.visit_key_regex) && valid_forms[key];
    if (ready) break;
  }
  return ready;
}

function num_forms_ready_for_upload() {
  var n = 0;
  for (var key in valid_forms) {
    if (key.match(options.visit_key_regex) && valid_forms[key]) n++;
  }
  return n;
}

function is_warehouse_form_uploaded_for(visit_month) {
  return valid_forms[get_warehouse_pickup_key(visit_month)] == 'accept';
}

function set_after_warehouse_link_status() {
  var visit_month = get_selected_value('visit_date_period');
  if (is_warehouse_form_uploaded_for(visit_month)) {
    $('#after-warehouse_link').addClass('complete');
    $('#after-warehouse-status').text(I18n.t('data_sources.hcvisit.fc_main.before.warehouse_form_uploaded',
                                             { visit_month: I18n.l(Date.from_date_period(visit_month),
                                                                  { format: 'month_of_year'}) }));
  } else {
    $('#after-warehouse_link').removeClass('complete');
    $('#after-warehouse-status').text('');
  }
}

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

function set_form_status(key, status) {
  var match = key.match(options.visit_key_regex);
  var f = this['set_'+match[1]+'_form_status'];
  if (typeof f == 'function') f(key, status);
}

function set_hc_form_status(key, status) {
  valid_forms[key] = status;
}

function set_wh_form_status(key, status) {
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
    var match = key.match(options.visit_key_regex);
    if (match && valid_forms[key]) {
      local_forms.push('<li id="' + key.replace('/','_') + '" class="status ' + (valid_forms[key] ? 'complete' : 'todo') + '"><span>' + get_visit_label_for(match[1], key) + '</span></li>');
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
        set_form_status(key, 'reject');
        alert(textStatus);
      },
      success: function(data, textStatus, xhr) {
        set_form_status(key, 'accept');
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

function get_visit_label_for(type, key) {
  var f = this['get_'+type+'_visit_label_for'];
  return (typeof f == 'function') ? f(key) : '- bad type ('+type+') for key ('+key+') -';
}

function get_hc_visit_label_for(key) {
  var v = key.split('/');
  return find_health_center_by_code(v[2]).name + ', ' + I18n.l(Date.from_date_period(v[0]), { format: 'month_of_year'});
}

function get_wh_visit_label_for(key) {
  var v = key.split('/');
  return find_warehouse_by_code(v[2]).name + ', ' + I18n.l(Date.from_date_period(v[0]), { format: 'month_of_year'});
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
  set_after_warehouse_link_status();
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

function save_warehouse_visit() {
  serialize_warehouse_visit();
  set_wh_form_status(get_warehouse_pickup_key(), update_warehouse_pickup_status());
  localStorage['valid forms'] = JSON.stringify(valid_forms); 
}

function serialize_warehouse_visit() {
  _serialize_instance_for(get_warehouse_pickup_key(), pickup_instance);
}

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
  
  if (get_selected_value('logged_in')) {
    var screen = get_hash_param('container');

    if (screen)
      show_container(screen);
    else
      show_main_page();
  } else {
    show_container(containers.login);
  }

  setup_visit_search();

  if ($('html').attr('manifest')) {
    //var statuses = ['cached', 'checking', 'downloading', 'error', 'noupdate', 'obsolete', 'progress', 'updateready'];

    applicationCache.addEventListener('error',       do_error,    true);
    applicationCache.addEventListener('noupdate',    do_noupdate, true);
    applicationCache.addEventListener('downloading', do_download, true);
    applicationCache.addEventListener('progress',    do_progress, true);
    applicationCache.addEventListener('updateready', do_update,   true);
    applicationCache.addEventListener('cached',      do_cached,   true);

    go_offline();

    if (options.update_check_interval > 0) {
      window.setInterval(check_update_status, options.update_check_interval);
    } else {
      window.setTimeout(check_update_status, 1);
    }
  }

  $('#upload-links a[href="#login"]').fancybox( 
    { 'hideOnContentClick': false,
      'autoScale': false,
      'autoDimension': true,
      'onComplete': check_logged_in });
  $('#upload-links a[href="#upload"]').fancybox( 
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
  var status = true;

  if (tabs) {
    tabs = $.makeArray(tabs);
    for (var i = 0, l = tabs.length; i < l; i++) {
      var e = typeof tabs[i] == "number" ? $('#tab-menu > ul > li')[tabs[i]] : $('#tab-'+tabs[i]);
      status &= set_progress_status_for(e);
    }
  } else {
    $('#tab-menu > ul > li').each(function(i,e) {
      status &= set_progress_status_for(e);
   });
  }

  return !!status;
}

function set_progress_status_for(element) {
  var link = $(element).find('a');
  link.removeClass("complete incomplete todo");

  // TODO: Cache results

  if ($(element).hasClass('ui-state-disabled')) return true;

  var valid = false;
  var div = $($('a', $(element)).attr('href'));
  var inputs = $('*:input.enabled', div);
  if (inputs.length > 0) {
    if (valid = inputs.valid()) {
      link.addClass("complete");
    } else {
      var invalid_count = inputs.map(function() { return $(this).parents('.invalid')[0]; }).length;
      var   valid_count = inputs.map(function() { return $(this).parents('.valid')[0]; }).length;
      link.addClass(valid_count > 0 && invalid_count > 0 ? "incomplete" : "todo");
    }
  } else {
    link.addClass("todo");
  }

  return valid;
}

function update_warehouse_pickup_status() {
  var status = false;
  var inputs = $('#warehouse-after input.enabled');
  if (inputs.length > 0) status = inputs.valid();
  return !!status;
}

function preinitialize_visit() {
  // Run actions that must be performed *after* visit form is reset but
  // *before* health center bindings are installed

  $('#visit-form *:input').not('.expression').addClass('enabled');
  
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
  fixup_menu_tabs();
  add_screen_sequence_tags();
}

function initialize_visit() {
  // Run actions that must be performed *after* health center bindings are 
  // installed
  
  $('#visit-form').addFormGridEvents();

  $('#visit-form *:input').blur(serialize_visit);
  $('#visit-form').setup_selected_values();
  
  $('#visit-form div.datepicker').each(function(i, e) {
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
  $('input[data-required*="unless_nr="]', $('#visit-form')).each(function(i, e) {
    var nrid = get_nrid(e);
    var nr = $('#'+nrid, $(e).parents('.tally').first())
    nr.change(function() {
      if ($(this).attr('checked')) {
        $(e).val('');
        $(e).change();
      }
      $(e).valid();
    });
    
    $(e).change(function() { 
      if ($(this).val().length > 0) {
        var nr = $('#'+get_nrid(this), $(this).parents('.tally'));
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

function get_nrid(element) {
  var required_data = $(element).attr('data-required');
  if (required_data) {
    var nr = required_data.split(/\s+/).filter(function(str) { return str.match(/^unless_nr=/); });
    if (nr.length == 1) {
      return nr[0].split('=')[1];
    }
  }
  return null;
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

  $('#warehouse_visit-form div.datepicker').each(function(i, e) {
    var date = Date.from_date_period(get_selected_value('visit_date_period'));
    var dp = setup_datepicker($('input[type="text"]', $(e))[0],
                              {
                                onSelect: function(dateText, inst) { $(this).valid(); },
                                minDate:  date.beginning_of_month(),
                                maxDate:  new Date(Math.min(date.end_of_month(), Date.today()))
                             });
  });

  $('#warehouse_visit-form *:input.enabled').valid();
}
