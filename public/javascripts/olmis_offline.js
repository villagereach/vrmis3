var online = true;
var valid_forms = {};
var manifest_files = {
  count:      1,
  downloaded: 0
};
var containers = {
  login:     'login-form',
  admin:     'admin-home',
  manager:   'manager-home',
  context:   'context-selector',
  actions:   'main-page',
  hc:        'location-selector',
  visit:     'form',
  wh_before: 'warehouse-before',
  wh_after:  'warehouse-after'
};
var roles_screens = {
  fc:      'context',
  manager: 'manager',
  admin:   'admin'
}
var container_hooks = {
  hide: {},
  show: {},
}

container_hooks.show['location-selector'] = function() {
  setup_visits();
}

container_hooks.hide['form'] = function() {
  var key = get_selected_value('visit_date_period') + '/' + get_selected_value('health_center');
  var valid = true;
  
  $('#tab-menu > ul > li').each(function(i,e) {
    if(!$(e).hasClass('ui-state-disabled')) {
      var div = $($('a', $(e)).attr('href'));
      var inputs = $('*:input.enabled', div);
      if (inputs.length > 0 && !inputs.valid())
        valid = false;
    }
  });  

  set_hc_form_status(key, valid);
};

var options = {
  months_to_show: 6,
  autoset_default_visit_date: true
};

function fixup_menu_tabs() {
  jQuery('#tab-menu a').each(function() {
    jQuery(this).focus(function() {
      jQuery(this).blur();
    });
  });
}

function update_visit_navigation() {
  // Adjust form container size to be at least as tall as the menu
  //jQuery("#form-contents .xforms-switch .xforms-case div.block-form").css("min-height", jQuery("#tab-menu").css("height"));

  // Hide the previous link on the first screen and the next link on the last screen
  var visible_tabs = jQuery("#tab-menu > ul > li:visible");
  var first_screen = visible_tabs.slice(0,1)[0].id.replace('tab-', 'screen-');
  var last_screen  = visible_tabs.slice(-1)[0].id.replace('tab-', 'screen-');
  jQuery("#" + first_screen + " .nav-links a:first").hide();
  jQuery("#" + last_screen + " .nav-links a:last").hide();
}

function go_to_next_screen(this_screen) {
  var t = $('#tab-menu').tabs();
  $("#tab-" + this_screen).nextAll().not(".ui-state-disabled").first().find('a').click()
}

function go_to_previous_screen(this_screen) {
  var t = $('#tab-menu').tabs();
  $("#tab-" + this_screen).prevAll().not(".ui-state-disabled").first().find('a').click()
}

function setup_fridge_form() {
  var temp_input = jQuery('#case-cold_chain .fridge-temp input');
  if (temp_input.siblings().length == 0) {
    jQuery('<span>' + I18n.t("visits.health_center_cold_chain.temp_input_prefix") + '</span>').insertBefore(temp_input);
    jQuery('<span>' + I18n.t("visits.health_center_cold_chain.temp_input_suffix") + '</span>').insertAfter(temp_input);

    // Shift nodes so that the alert icon precedes the input field, except for the other problem text area
    jQuery('#case-cold_chain span.value').each(function() {
      if (jQuery(this).children()[0].nodeName.toLowerCase() != 'textarea') {
        jQuery(this).insertAfter(jQuery(this).next());
      }
    });
  }
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
  $(data_instance.selected_values).attr(name, value);
}

function get_selected_value(name) {
  return data_instance.selected_values[name]
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

function find_health_center_by_code(dz) {
  return find_health_centers_by_attr('code', dz)[0];
}

function find_health_centers_by_attr(attr, value) {
  return $(data_instance.health_centers).filter(function(i) { return this[attr] == value })
}

function populate_warehouse_pickups() {
  try {
    var pickup_amounts = get_warehouse_stock_amounts_for_delivery_zone();

    var xf_action = new XFAction(null, null);
    for (var key in pickup_amounts) {
      var path = "instance('pickups')/item[@for='"+key+"']/@DeliveryRequest";

      // Create an XPath (required by setvalue) for the item node if it doesn't already exist
      var xp = XPath.get(path) || new XPath(path,
                                    new PathExpr(
                                      new FunctionCallExpr('http://www.w3.org/2002/xforms instance', new CteExpr('pickups')),
                                      new LocationExpr(false,
                                        new StepExpr('child', new NodeTestName('', 'item'),
                                          new PredicateExpr(
                                            new BinaryExpr(
                                              new LocationExpr(false, new StepExpr('attribute', new NodeTestName(null, 'for'))),
                                              '=',
                                              new CteExpr(key)))),
                                        new StepExpr('attribute', new NodeTestName('', 'DeliveryRequest')))), []);

      xf_action.add(new XFSetvalue(new Binding(false, path), null, pickup_amounts[key], null, null));
    }
    run(xf_action, "statusPanel", "DOMActivate", false, true);
  } catch(e) {
    DebugConsole.write("Error populating warehouse pickup amounts: " + e.message + "\n" + e.stack.split("\n"));
  }
}

function get_warehouse_stock_amounts_for_delivery_zone() {
  var path = "instance('data')/province/delivery_zone[@code=instance('data')/selected-values/delivery_zone]/ideal_stock";
  var xp = XPath.get(path) || new XPath(path,
                                new PathExpr(
                                  new FunctionCallExpr('http://www.w3.org/2002/xforms instance', new CteExpr('data')),
                                    new LocationExpr(false,
                                       new StepExpr('child', new NodeTestName('', 'province')),
                                       new StepExpr('child',
                                         new NodeTestName('', 'delivery_zone'),
                                          new PredicateExpr(
                                            new BinaryExpr(
                                              new LocationExpr(false, new StepExpr('attribute', new NodeTestName(null, 'code'))),
                                              '=',
                                              new PathExpr(
                                                new FunctionCallExpr('http://www.w3.org/2002/xforms instance', new CteExpr('data')),
                                                  new LocationExpr(false,
                                                    new StepExpr('child', new NodeTestName('', 'selected-values')),
                                                    new StepExpr('child', new NodeTestName('', 'delivery_zone'))))))),
                                      new StepExpr('child', new NodeTestName('', 'ideal_stock')))), []);
  var nodeset = xp.evaluate($('data'));
  var stock_amounts = {};
  for (var i = 0, l = nodeset.length; i < l; i++) {
    stock_amounts[nodeset[i].getAttributeNS(null, 'for')] = nodeset[i].getAttributeNS(null, 'qty');
  }
  return stock_amounts;
}

function populate_fridge_form() {
  try {
    var fridge_codes = get_fridge_codes_for_health_center();

    if (fridge_codes.length > 0) {
      var xf_action = new XFAction(null, null);

      for (var i = 0, l = fridge_codes.length; i < l; i++) {
        var path = "instance('olmis')/cold_chain/fridge["+(i+1)+"]/@code"

        // Create an XPath (required by setvalue) for the fridge code node if it doesn't already exist
        var xp = XPath.get(path) || new XPath(path,
                                      new PathExpr(
                                        new FunctionCallExpr('http://www.w3.org/2002/xforms instance', new CteExpr('olmis')),
                                        new LocationExpr(false,
                                          new StepExpr('child', new NodeTestName('', 'cold_chain')),
                                          new StepExpr('child', new NodeTestName('', 'fridge'),
                                            new PredicateExpr(new CteExpr(i+1))),
                                          new StepExpr('attribute', new NodeTestName('', 'code')))), []);

        xf_action.add(new XFSetvalue(new Binding(false, path), null, fridge_codes[i], null, null));
      }
      run(xf_action, "statusPanel", "DOMActivate", false, true);
    }
  } catch(e) {
    DebugConsole.write("Error populating fridge form: " + e.message + "\n" + e.stack.split("\n"));
  }
}

function get_fridge_codes_for_health_center() {
  var path = "instance('data')/province/district/health_center[@code=instance('data')/selected-values/health_center]/fridge";
  var xp = XPath.get(path) || new XPath(path,
                                new PathExpr(
                                  new FunctionCallExpr('http://www.w3.org/2002/xforms instance', new CteExpr('data')),
                                    new LocationExpr(false,
                                       new StepExpr('child', new NodeTestName('', 'province')),
                                       new StepExpr('child', new NodeTestName('', 'district')),
                                       new StepExpr('child',
                                         new NodeTestName('', 'health_center'),
                                          new PredicateExpr(
                                            new BinaryExpr(
                                              new LocationExpr(false, new StepExpr('attribute', new NodeTestName(null, 'code'))),
                                              '=',
                                              new PathExpr(
                                                new FunctionCallExpr('http://www.w3.org/2002/xforms instance', new CteExpr('data')),
                                                  new LocationExpr(false,
                                                    new StepExpr('child', new NodeTestName('', 'selected-values')),
                                                    new StepExpr('child', new NodeTestName('', 'health_center'))))))),
                                      new StepExpr('child', new NodeTestName('', 'fridge')))), []);

  var nodeset = xp.evaluate($('data'));
  var fridge_codes = [];
  for (var i = 0, l = nodeset.length; i < l; i++) {
    fridge_codes.push(nodeset[i].getAttributeNS(null, 'code'));
  }
  return fridge_codes;
}

/*
XFSelect.prototype.selectValue = function(value) {
  var selectElement = this.element.getElementsByTagName('select')[0];
  for (var x = 0, l = selectElement.options.length; x < l; x++) {
    if (selectElement.options[x].value == value) {
      selectElement.selectedIndex = x;
      var event = document.createEvent('HTMLEvents');
      event.initEvent('change', false, false);
      selectElement.dispatchEvent(event);
      break;
    }
  }
}
*/
function select_visit() {
  var key = $('#saved-forms-control').val();
  if (!key) {
    return;
  }

  setTimeout(function() {
    var selection = key.split('/', 2);
    var ym = selection[0];
    var hc = selection[1];

    var health_center = find_health_center_by_code(hc);
    
    set_selected_value('health_center', hc);

    reset_olmis_instance(key);
    
    show_container(containers['visit']);
    update_visit_navigation();
    setup_fridge_form();
  }, 1);
}

function reset_olmis_instance(key) {
  var instance = localStorage.getItem(key);
  if (instance)
    olmis_instance = JSON.parse(instance);
  else {
    olmis_instance = generate_olmis_instance(); 
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

  if (container_hooks.show[container])
    container_hooks.show[container].call()
  
  jQuery('body > .container').hide();
  jQuery('body > #'+container).show();
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
  set_selected_value('logged_in',   false);
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

  set_selected_value('visit_period_selected', 'true()');
  show_container(containers['actions']);
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
  landing_page = landing_page || roles_screens[get_selected_value('access_code')];

  set_selected_value('health_center', '');
  set_selected_value('visit_period_selected', false);
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
    ready = key.match(/^[\d\-]+\/.+$/) && valid_forms[key];
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
      visit_key = keys[hci][0] + '/' + keys[hci][1];
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
    for (var idx=0; idx < hcs.length; idx++) {
      var name = hcs[idx].name;
      var code = hcs[idx].code;
      
      var key = [month, code, name];
      
      if (local_forms[hcs[idx].area_code] === undefined)
        local_forms[hcs[idx].area_code] = []
      
      local_forms[hcs[idx].area_code].push(key);
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

/*
XFSubmission.prototype.submitWithoutLocalStore = XFSubmission.prototype.submit
XFSubmission.prototype.submit = function() {
  this.validate = (typeof this.validate == 'boolean') ? this.validate : !(this.validate == 'false');

  var action = possiblyEvaluatableValue(this.action, "error");
  
  xforms.openAction();

  if (action.substr(0,8) == "local://") {
    var key = action.substr(8);
    var method = possiblyEvaluatableValue(this.method, "post").toLowerCase();

    if(method == 'get' && this.replace == "instance" && localStorage[key]) {
      try {
        var inst = this.instance == null? this.model.getInstance() : $(this.instance).xfElement;
        inst.setDoc(localStorage[key], true);
        XMLEvents.dispatch(this.model, "xforms-rebuild");
        XMLEvents.dispatch(this.model, "xforms-revalidate");
        XMLEvents.dispatch(this, "xforms-model-construct-done"); 
        XMLEvents.dispatch(this, "xforms-submit-done");

        xforms.refresh();

        var node = this.eval_();
        set_hc_form_status(key, validate_(node));

        setup_visits();
      } catch(e) {
        DebugConsole.write("local storage failed");
        xforms.error(this.element, "xforms-submit-error",
          "Fatal error loading " + key + ": " +  e.toString());
      }
    } else if(method == 'delete') {
      clearTimeout(save_timeouts[key]);
      localStorage.removeItem(key);
      setup_visits();
      select_visit();
    } else if(method == 'put') {
      var node = this.eval_();
      clearTimeout(save_timeouts[key]);
      save_timeouts[key] = setTimeout((function(_this, _node, _key, _action) { return function() {
        if (_action === 'accept' || _action === 'reject') {
          set_hc_form_status(_key, _action);
        } else {
          _node.valid = validate_(_node);
  
          set_hc_form_status(_key, _node.valid);
          localStorage[_key] = Writer.toString(_node);
        }
        XMLEvents.dispatch(_this, "xforms-submit-done");
      }; })(this, node, key, this.element.id), 1000);
    } else {
      XMLEvents.dispatch(this, "xforms-submit-error");
    }
  } else {
    this.submitWithoutLocalStore()
  }

  xforms.closeAction();
}

XPathCoreFunctions['http://openrosa.org/javarosa selected'] =  new XPathFunction(false, XPathFunction.DEFAULT_NONE, false,
    function(nodeSet, str) {
      return xmlValue(nodeSet[0]) == str;
    } );

XPathCoreFunctions['http://openrosa.org/javarosa regex'] =  new XPathFunction(false, XPathFunction.DEFAULT_NONE, false,
    function(nodeSet, re) {
      return new RegExp(re).test(stringValue(nodeSet));
    } );

XPathCoreFunctions['http://openrosa.org/javarosa date'] =  new XPathFunction(false, XPathFunction.DEFAULT_NODESET, false,
    function(node) {
      var str = stringValue(node);
      var d, m;
      
      if (m = /^\s*([0-9][0-9][0-9][0-9])-([0-9][0-9])\s*-([0-9][0-9])\s*$/.exec(str)) {
        d = new Date(parseInt(m[1],10), parseInt(m[2],10) - 1, parseInt(m[3],10));
      } else if (m = /^\s*(\d+)\s*$/.exec(str)) {
        var millis = Date.parse(str);
        if (isNaN(millis)) return false;
        d = new Date(millis);
      } else {
        region = jQuery.datepicker.regional[I18n.locale] || jQuery.datepicker.regional[''] 
        d = jQuery.datepicker.parseDate(region['dateFormat'], str);
      }
      
      return d.format("%Y-%m-%d");
    } );

XPathCoreFunctions['http://openrosa.org/javarosa today'] =  new XPathFunction(false, XPathFunction.DEFAULT_NODESET, false,
    function(str) {
      return new Date().format("%Y-%m-%d");
    } );
  
XPathCoreFunctions['http://www.w3.org/2005/xpath-functions exists'] =  new XPathFunction(false, XPathFunction.DEFAULT_NONE, false,
    function(local) {
      local = stringValue(local);
      
      if (local == '')
        return false;

      if (local.substr(0,8) == "local://" && local.substr(8).match(/^\d{4}-\d{2}\/.+$/))
        return !!localStorage[local.substr(8)];

      return false;
    } );

XPathCoreFunctions['http://openlmis.org/xpath-functions previous_yearmonth'] =  new XPathFunction(false, XPathFunction.DEFAULT_NODESET, false,
    function(yearmonth) {
      ym = stringValue(yearmonth);
     
      return ym.match(/^\d{4}-\d{2}$/) ? Date.from_date_period(ym).previous_month().to_date_period() : '';
    });


XPathCoreFunctions['http://openlmis.org/xpath-functions date_to_local'] =  new XPathFunction(false, XPathFunction.DEFAULT_NODESET, false,
    function(date, datepicker_id) {
      var d = stringValue(date);
      var result = '';

      if (d.match(/^\d{4}-\d{2}-\d{2}$/)) {
        try {
          var dp = jQuery(datepicker_id || '#case-visit div.datepicker input[type="text"]');
          result = jQuery.datepicker.formatDate(dp.datepicker('option', 'dateFormat'), jQuery.datepicker.parseDate(jQuery.datepicker.ISO_8601, d));
        } catch(e) {}
      }
      return result;
    });

XPathCoreFunctions['http://openlmis.org/xpath-functions date_from_local'] =  new XPathFunction(false, XPathFunction.DEFAULT_NODESET, false,
    function(date, datepicker_id) {
      var d = stringValue(date);
      var result = '';

      if (d.match(/\d/)) {
        try {
          var dp = jQuery(datepicker_id || '#case-visit div.datepicker input[type="text"]');
          result = jQuery.datepicker.formatDate(jQuery.datepicker.ISO_8601, jQuery.datepicker.parseDate(dp.datepicker('option', 'dateFormat'), d));
        } catch(e) {}
      }
      return result;
    });

XPathCoreFunctions['http://openlmis.org/xpath-functions month_of_year'] =  new XPathFunction(false, XPathFunction.DEFAULT_NODESET, false,
    function(yearmonth) {
      ym = stringValue(yearmonth);
     
      return ym.match(/^\d{4}-\d{2}$/) ? I18n.l(Date.from_date_period(ym), { format: 'month_of_year' }) : '';
    });

XPathCoreFunctions['http://openlmis.org/xpath-functions currently_online'] =  new XPathFunction(false, XPathFunction.DEFAULT_NONE, false,
    function() {
      return navigator.onLine;
    });

XPathCoreFunctions['http://openlmis.org/xpath-functions sort'] =  new XPathFunction(false, XPathFunction.DEFAULT_NONE, false,
    function(arr) {
        // Sort an array of strings
        return arr.sort(function(a,b) {
                var s1 = xmlValue(a);
                var s2 = xmlValue(b);
                return (s1 == s2 ? 0 : (s1 > s2 ? 1 : -1));
            });
    });
*/

function radioValueFn(val) {
  return function(ev) {
    return((ev == val) ? 'checked' : false);
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

function setup_saved_visits() {
  var local_forms = [];

  forEachLocalStorageKey(function(key) {
      if (key.match(/^[\d\-]+\/.+$/) && valid_forms[key]) {
        local_forms.push('<li id="' + key.replace('/','_') + '" class="status ' + (valid_forms[key] ? 'complete' : 'todo') + '"><span>' + key + '</span></li>');
        setTimeout((function(k) { return function() { find_correct_label(k) }; })(key), 1);
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
    for (var x = 0, l = localStorage.length; x < l; x++)  {
      f(localStorage[x]);
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

function find_correct_label(key) {
  $.ajax( { 
      async: true,
      data: null,
      url: '/visits/' + key + '/title',
      dataType: 'html',
      type: 'GET',
      success: function(data, textStatus, xhr) { $('#'+key.replace('/','_')+' span').html(data); },
  } );
}

function upload_all() {
  $('#upload-ready li.complete').each(function(i,n) { upload(n, false) });
}

function is_logged_in() {
  $('#other-actions a[href="#upload"]').click();
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

function serialize_visit() {
  var key = get_selected_value('visit_date_period') + '/' + get_selected_value('health_center');
  localStorage[key] = JSON.stringify(olmis_instance).
    replace(/,"jQuery[0-9]+":[0-9]+/g, '').
    replace(/{"jQuery[0-9]+":[0-9]+,/g, '{');
}



$(function() {
  show_container(containers['login']);
  $('#saved-forms-control').change(select_visit);
  
  try {
    valid_forms = JSON.parse(localStorage['valid forms']) || {};
  } catch(e) {
    valid_forms = {};
  }
  
  setup_visit_search();

  /*
  window.setInterval(check_update_status, 3 * 1000);
  
  var statuses = ['cached', 'checking', 'downloading', 'error', 'noupdate', 'obsolete', 'progress', 'updateready'];

  applicationCache.addEventListener('error',       go_offline,  true);
  applicationCache.addEventListener('noupdate',    go_online,   true);
  applicationCache.addEventListener('downloading', do_download, true);
  applicationCache.addEventListener('progress',    do_progress, true);
  applicationCache.addEventListener('updateready', do_update,   true);
  applicationCache.addEventListener('cached',      do_cached,   true);
  */  
  /*
  fixup_menu_tabs();

  go_offline();
  */
  $('#other-actions a[href="#login"]').fancybox( 
    { 'hideOnContentClick': false,
      'autoScale': false,
      'autoDimension': true,
      'onComplete': check_logged_in });
  $('#other-actions a[href="#upload"]').fancybox( 
    { 'hideOnContentClick': false,
      'autoScale': false,
      'autoDimension': true,
      'onComplete': setup_saved_visits,
      'onClosed': finish_upload });
});

function add_screen_sequence_tags() {
  $("#tab-menu div.ui-tabs-panel span.seqno").each(function(i,e) { $(e).html(i+1); });
}

function preinitialize_visit() {
  // Run actions that must be performed *after* visit form is reset but
  // *before* health center bindings are installed

  $('#visit-form *:input').addClass('enabled');
  
  $('#visit-form').setupValidation();

  $('#tab-menu').tabs({
    show: function(event, ui) {
      $('*:input', $(ui.panel)).valid();
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
  $('div.nr input[type="checkbox"]').change(function() {
    var associated_field = $(this).parent().prev();
    if ($(this).attr('checked')) {
      associated_field.val('');
    }
    // Also need to perform a validation check so that a checked field doesn't continue to show as
    // invalid (or a newly unchecked field with no associated field value continues to show as valid)
    associated_field.valid();
  }).parent().prev().change(function() {
    if ($(this).val().length > 0) {
      $(this).next().find('input').attr('checked', false);
    }
  });

  // Show the first (visit) screen rather than the last screen viewed, possibly
  // for a different health center. However, the screen's validations are not
  // run unless another screen is selected first (so select the last screen before
  // selecting the first screen).
  $('#tab-menu').tabs('select', $('#tab-menu').tabs('length')-1);
  $('#tab-menu').tabs('select', 0);
}

