var online = true;
var valid_forms = {};
var manifest_files = {
  count:      1,
  downloaded: 0
};
var containers = {
  login: 'login-form',
  main:  'context-selector',
  hc:    'location-selector',
  visit: 'form'
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

function fixup_form_container_size() {
  // Adjust form container size to be at least as tall as the menu
  jQuery('.xforms-switch .xforms-case div.block-form').css('min-height', jQuery('#tab-menu').css('height'));
}

function fixup_nr_checkboxes() {
  jQuery('div.nr span.value').each(function() {
    jQuery(this).insertBefore(jQuery(this).prev());
  });
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
  var ta = jQuery('#div-equipment_status .xforms-textarea textarea');
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

function set_active_tab(tab) {
  jQuery('.menu-tab').removeClass('selected-tab');
  jQuery('.menu-tab[id="tab-'+tab+'"]').addClass('selected-tab');
}

function get_available_visit_months() {
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

function setup_visit_months() {
  xforms.openAction();

  var month_selector = jQuery('#visit-month-selector');
  var select_control = month_selector.find('select');
  select_control.empty();

//  var ul = jQuery(document.createElement('ul'));
//  ul.attr('id', 'visit-month-menu');

  var months = get_available_visit_months();
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

//    var li = jQuery(document.createElement('li'));
//    li.attr('id', 'month_'+month_value);
//
//    var span = jQuery(document.createElement('span'));
//    span.text(month_text);
//    span.click(function(item, value) {
//      return function() {
//        if (!item.hasClass('disabled')) {
//          item.parent().siblings().find('span').removeClass('selected');
//          item.addClass('selected');
//          set_selected_value('health_center', '');
//          $('visit-month-selector').xfElement.selectValue(value);
//        }
//      };
//    }(span, month_value));
//
//    li.append(span);
//    ul.append(li);
  }

//  month_selector.parent().append(ul);
//  month_selector.hide();

  xforms.closeAction();
}

function set_selected_value(name, value) {
  var ctx = $('data');
  if (!ctx) {
    DebugConsole.write('No data instance found');
    return;
  }

  var literal_value = !value.match(/\([^)]*\)/);  // Does value look like a function call?
  var xf_setvalue = new XFSetvalue(new Binding(false, "instance('data')/selected-values/"+name),
                                   literal_value ? null : value,
                                   literal_value ? value : null,
                                   null, null);
  var xf_action = new XFAction(null, null).add(xf_setvalue);

  run(xf_action, "statusPanel", "DOMActivate", false, true);
}

function get_selected_value(name) {
  var ctx = $('data');
  if (!ctx) {
    DebugConsole.write('No data instance found');
    return null;
  }
  
  var xp = new XPath("instance('data')/selected-values/"+name,
             new PathExpr(
               new FunctionCallExpr('http://www.w3.org/2002/xforms instance', new CteExpr('data')),
               new LocationExpr(false,
                 new StepExpr('child', new NodeTestName('', 'selected-values')),
                 new StepExpr('child', new NodeTestName('', name)))), []);

  var nodeset = xp.evaluate(ctx);

  return nodeset.length > 0 ? nodeset[0].getTextContent() : null;
}

function find_province_district_health_center(hc) {
  var xp = new XPath("instance('data')/province/district/health_center[@code='"+hc+"']",
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
                       new CteExpr(hc)))))), []);

  var nodeset = xp.evaluate($('data'));
  
  if (nodeset.length > 0)
    return [nodeset[0].parentNode.parentNode.getAttributeNS(null, 'name'), // province
            nodeset[0].parentNode.getAttributeNS(null, 'name'),            // district
            nodeset[0].getAttributeNS(null, 'code'),                       // health_center
            nodeset[0].getAttributeNS(null, 'dz'),                         // delivery_zone
            get_selected_value('field_coordinator')];                      // field_coordinator
  else
    return null;
}

function find_health_centers_in_delivery_zone(dz) {
  return find_health_centers_by_attr('dz', dz);
}

function find_health_center_by_code(dz) {
  return find_health_centers_by_attr('code', dz)[0];
}

function find_health_centers_by_attr(attr, value) {
  if (!value || !attr) return null;

  var xp = new XPath("instance('data')/province/district/health_center[@"+attr+"='"+value+"']",
             new PathExpr(
               new FunctionCallExpr('http://www.w3.org/2002/xforms instance', new CteExpr('data')),
               new LocationExpr(false,
                 new StepExpr('child', new NodeTestName('', 'province')),
                 new StepExpr('child', new NodeTestName('', 'district')),
                 new StepExpr('child',
                   new NodeTestName('', 'health_center'),
                   new PredicateExpr(
                     new BinaryExpr(
                       new LocationExpr(false, new StepExpr('attribute', new NodeTestName(null, attr))),
                       '=',
                       new CteExpr(value)))))), []);
  return xp.evaluate($('data'));
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

function select_visit() {
  var savedVisits = $('saved-forms-control');
  if (savedVisits.selectedIndex == -1) {
    return;
  }

  xforms.openAction();

  Dialog.show("statusPanel");

  setTimeout(function() {
    var key = savedVisits.options[savedVisits.selectedIndex].value;
    if (xforms.focus) {
      xforms.blur();
    }

    var selection = key.split('/', 2);
    var ym = selection[0];
    var hc = selection[1];
    var pdh = find_province_district_health_center(hc);

    if (!!pdh) {
      $('health-center-selector').xfElement.selectValue(hc);
      $('visit-month-selector').xfElement.selectValue(ym);
    }
    Dialog.hide("statusPanel");
    show_container(containers['visit']);
    fixup_form_container_size();
    setup_fridge_form();
  }, 1);
  
  xforms.closeAction();
}

function show_container( container ) {
  jQuery('.container').hide();
  jQuery('body #'+container).show();
}

function login() {
  // FIXME: Implement something more than a trivial check
  if (get_selected_value('access_code').length > 0) {
    set_selected_value('logged_in', 'true()');
    show_main_page();
  }
}

function logout() {
  set_selected_value('access_code', '');
  set_selected_value('logged_in', 'false()');
  show_container(containers['login']);
  jQuery('#login-form input').each(function() { jQuery(this).val(''); }).slice(0,1).focus();
}

function select_location() {
  //jQuery('#visit-month-menu span').removeClass();  // reset to empty state

  var today = Date.today();
  var date = Date.from_date_period(get_selected_value('visit_date_period'));
  var dp = jQuery('#case-visit div.datepicker input[type="text"]');
  dp.datepicker('option', 'minDate', date.beginning_of_month());
  dp.datepicker('option', 'maxDate', new Date(Math.min(date.end_of_month(), today)));
  if (options['autoset_default_visit_date']) {
    var default_visit_date = date.getMonth() == today.getMonth() ? today : date.beginning_of_month();
    set_selected_value('default_visit_date', default_visit_date.format('%Y-%m-%d'));
  }

  set_selected_value('visit_period_selected', 'true()');
  show_visits();
}

function show_visits() {
  setup_visits();
  // If no month is currently selected, autoselect the first month that is not finished
  //if (jQuery('#visit-month-menu span.selected').length === 0) {
  //  jQuery('#visit-month-menu li:not(.accept):first').find('span').click();
  //}
  show_container(containers['hc']);
}

function show_main_page() {
  set_selected_value('health_center', '');
  set_selected_value('visit_period_selected', 'false()');
  show_or_hide_upload_link();
  show_container(containers['main']);
}

function show_or_hide_upload_link() {
  if (has_forms_ready_for_upload()) {
    jQuery("#upload_link").addClass("online").removeClass("offline");
  } else {
    jQuery("#upload_link").removeClass("online").addClass("offline");
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
  
  var health_center = get_context_path_value($('olmis'), '/health_center_visit/health_center')[0].getTextContent();
  var date_period   = get_context_path_value($('olmis'), '/health_center_visit/visit_month')[0].getTextContent();
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

function visit_date_changed() {
  var date = get_context_path_value($('olmis'), '/health_center_visit/visited_at')[0].getTextContent();
  update_visit_history({ 'visit': date });
}

function non_visit_reason_changed() {
  var reason = get_context_path_value($('olmis'), '/health_center_visit/non_visit_reason')[0].getTextContent();
  update_visit_history({ 'visit': reason });
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
  xforms.openAction();

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
      optgroup.attr('label', district);
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

  //if (month && statuses.length > 0) {
  //  var selected_month = jQuery('#month_'+month).removeClass();
  //  var overall_status = uniq(statuses);
  //  if (overall_status.length == 1) {
  //    var status = overall_status[0];
  //    selected_month.addClass(status);
  //    if (status === 'accept') {
  //      selected_month.find('span').removeClass('selected').addClass('disabled');
  //    }
  //  } else {
  //    // Multiple statuses were found so overall status is incomplete
  //    selected_month.addClass('incomplete');
  //  }
  //}

  xforms.closeAction();
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
  xforms.openAction();

  var hcs = find_health_centers_in_delivery_zone(get_selected_value('delivery_zone'));
  var months = get_available_visit_months();
  var month_period = get_selected_value('visit_date_period');

  localStorage['valid forms'] = JSON.stringify(valid_forms); 

  for (var i = 0, l = months.length; i < l; i++) {
    var month = months[i][0];
    var local_forms = [];
    for (var idx in hcs) {
      var name = hcs[idx].getAttributeNS(null, 'name');
      var code = hcs[idx].getAttributeNS(null, 'code');
      var district = hcs[idx].parentNode.getAttributeNS(null, 'name');
      var key = [month, code, name]
      if (!local_forms[district]) {
        local_forms[district] = [];
      }
      local_forms[district].push(key);
    }

    setup_form_options(local_forms, month_period != month);
  }

  xforms.closeAction();
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
      var d, m, dp = jQuery('#case-visit div.datepicker input[type="text"]');
      if (m = /^\s*([0-9][0-9][0-9][0-9])-([0-9][0-9])\s*-([0-9][0-9])\s*$/.exec(str)) {
        d = new Date(parseInt(m[1],10), parseInt(m[2],10) - 1, parseInt(m[3],10));
      } else if (dp.length > 0) {
        d = jQuery.datepicker.parseDate(dp.datepicker('option', 'dateFormat'), str);
      } else {
        var millis = Date.parse(str);
        if (isNaN(millis)) return false;
        d = new Date(millis);
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
  jQuery.ajax( { 
      async: do_sync,
      contentType: 'application/xml',
      data: localStorage[key],
      url: '/visits/' + key + '.xml',
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
  jQuery.ajax( { 
      async: true,
      data: null,
      url: '/visits/' + key + '/title',
      dataType: 'html',
      type: 'GET',
      success: function(data, textStatus, xhr) { jQuery('#'+key.replace('/','_')+' span').html(data); },
  } );
}

function upload_all() {
  jQuery('#upload-ready li.complete').each(function(i,n) { upload(n, false) });
}

function is_logged_in() {
  var evt = document.createEvent('MouseEvents')
  evt.initMouseEvent("click", true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 0, null);
  jQuery('#other-actions a[href="#upload"]')[0].dispatchEvent(evt);  
}

function check_logged_in() {
  jQuery('#login-login').focus();
  jQuery.ajax( { 
      async: true,
      url: '/logged-in?',
      type: 'GET',
      success: function(data, textStatus, xhr) {  
        is_logged_in();
      }
  } );
}

function ajax_login() {
  jQuery('#login-button').attr('disabled', true);
  jQuery.ajax( { 
      async: true,
      data: { 'login[username]': jQuery('#login-login').attr('value'), 'login[password]': jQuery('#login-password').attr('value') },
      url: '/login',
      dataType: 'html',
      type: 'POST',
      error: function (XMLHttpRequest, textStatus, errorThrown) {      
      },
      success: function(data, textStatus, xhr) {  
        is_logged_in();
      },
      complete: function(xhr, textStatus) {
        jQuery('#login-button').attr('disabled', false);
      }
  } );
}

function finish_upload() {
  setup_visits();
  jQuery('#upload-uploaded ul').empty();
}

jQuery(document).ready(function() {
  $('saved-forms-control').addEventListener('change', select_visit, true);
  window.setInterval(check_update_status, 3 * 1000);
  
  var statuses = ['cached', 'checking', 'downloading', 'error', 'noupdate', 'obsolete', 'progress', 'updateready'];

  applicationCache.addEventListener('error',       go_offline,  true);
  applicationCache.addEventListener('noupdate',    go_online,   true);
  applicationCache.addEventListener('downloading', do_download, true);
  applicationCache.addEventListener('progress',    do_progress, true);
  applicationCache.addEventListener('updateready', do_update,   true);
  applicationCache.addEventListener('cached',      do_cached,   true);
  
  try {
    valid_forms = JSON.parse(localStorage['valid forms']) || {};
  } catch(e) {
    valid_forms = {};
  }

  setup_visits();
  setup_visit_search();
  fixup_menu_tabs();

  go_offline();

  show_container(containers['login']);
  jQuery('#other-actions a[href="#login"]').fancybox( 
    { 'hideOnContentClick': false,
      'autoScale': false,
      'autoDimension': true,
      'onComplete': check_logged_in });
  jQuery('#other-actions a[href="#upload"]').fancybox( 
    { 'hideOnContentClick': false,
      'autoScale': false,
      'autoDimension': true,
      'onComplete': setup_saved_visits,
      'onClosed': finish_upload });
});

function xf_user_init() {
  // Run actions that must be performed *after* XSLTForms init() runs
  fixup_nr_checkboxes();  
  setup_datepicker('#div-visit div.datepicker input[type="text"]',
                   { onClose: function(dateText, inst) {
                                XMLEvents.dispatch($('olmis'), "xforms-value-changed");
                              },
                     altField: "#div-visit #iso_visit_date input",
                     altFormat: jQuery.datepicker.ISO_8601
                   });
}

