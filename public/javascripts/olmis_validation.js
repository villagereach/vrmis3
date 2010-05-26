(function($){
  $.each('min max required data-required'.split(' '),function(i,type){
    $.expr[":"][type] = function(elem){
        return typeof(elem.getAttribute(type)) == 'string';
    };
  });
})(jQuery);

function no_nr(element) {
  var nrid = get_nrid(element);
  if (nrid) {
    return !$('#'+nrid, $(element).parents('.tally').first()).attr('checked');
  }
  return true;
}

function related_checkbox(element) {
  var required_data = $(element).attr('data-required');
  if (required_data) {
    var cb = required_data.split(/\s+/).filter(function(str) { return str.match(/^related_checkbox=/); });
    if (cb.length == 1) {
      return $('#'+cb[0].split('=')[1]).attr('checked');
    }
  }
  return false;
}

function validateRequiredRadio(value, element) {
  var group = get_validation_container_for($(element));
  var btns = $('*[name='+element.name+']', $(group)).filter(function(i) { return this.checked; }); 
  return (btns.length > 0);
}

function validateRequiredCheckbox(value, element) {
  return validateRequiredRadio(value, element);  // Same validations as for radio buttons
}

function validateRequiredVisitDate(value, element) {
  var d = Date.from_date_period(get_selected_value('visit_date_period'));
  var date = $.datepicker.parseDate($(element).datepicker('option', 'dateFormat'), value);
  return date >= d.beginning_of_month() && date <= Math.min(d.end_of_month(), Date.today());
}

function validateRequiredYearMonth(value, element) {
  return this.optional(element) || value.match(/^0[1-9]|1[0-2]\/\d{4}$/);
}

function add_notice(container) {
  var notice = get_notice(container);
  if (notice.length == 0) {
    container.append('<span class="notice"></span>');
    notice = $('.notice', container);
  }
  return notice;
}

function get_notice(container) {
  return $('.notice', container);
}

function escape_metas(str) {
  var re = new RegExp('([#;&,.\\+\\*~\':"!^$\\[\\]()=>|/])', 'g');
  return str.replace(re, '\\$1');
}

function show_errors(errorMap, errorList) {
  for (var k in errorMap) {
    if (k) {
      var container = get_validation_container_for($('*:input[name='+escape_metas(k)+']'));
      var notice = add_notice(container);
      notice.attr('title', errorMap[k]);
      container.removeClass('valid').addClass('invalid');
    }
  }
  this.validElements().each(function(i,e) { 
    if (e.name.length > 0 &&
        (e.getAttribute('required') != undefined || e.getAttribute('required_unless_nr') != undefined) &&
        !errorMap[e.name]) {
      var container = get_validation_container_for($(e));
      var notice = get_notice(container);
      if (notice) notice.removeAttr('title');
      container.removeClass('invalid').addClass('valid');
    }
  });
}

// Return the given element's first ancestor with class="validation-group" or,
// if no such ancestor exists, the given element's parent.
function get_validation_container_for(element) {
  var group = element.parents(".validation-group").first();
  if (group.length == 0) group = element.parent();
  return group;
}

$.validator.addMethod('required_radio',      validateRequiredRadio,     $.validator.messages.required);
$.validator.addMethod('required_checkbox',   validateRequiredCheckbox,  $.validator.messages.required);
$.validator.addMethod('required_visit_date', validateRequiredVisitDate, $.validator.messages.required);
$.validator.addMethod('required_year_month', validateRequiredYearMonth, $.validator.messages.required);

$.extend($.fn, {
  setupValidation: function() {
    this.validate( {
      onkeyup: false,
      showErrors: show_errors
    } );

    $('*:input:text[required]:not([data-required*="unless_nr="])', this).each(function(i,e) { $(e).rules('add', { required: true }); });
    $('*:input:text[data-required*="unless_nr="]', this).each(function(i,e) { $(e).rules('add', { required: { depends: no_nr } }); });
    $('select[required]',           this).each(function(i,e) { $(e).rules('add', { required: true }); });
    $('textarea[required]:not([data-required*=""])', this).each(function(i,e) { $(e).rules('add', { required: true }); });
    $('textarea[data-required*="related_checkbox="]', this).each(function(i,e) { $(e).rules('add', { required: { depends: related_checkbox } }); });
    $('*:input:radio[required]',    this).each(function(i,e) { $(e).rules('add', { required_radio: true }); });
    $('*:input:checkbox[required]', this).each(function(i,e) { $(e).rules('add', { required_checkbox: true }); });
    $('*:number',     this).each(function(i,e) { $(e).rules('add', { digits: { depends: no_nr, param: true } }); });
    $('*:input:date', this).each(function(i,e) { $(e).rules('add', { date:   { depends: no_nr, param: true } }); });
    $('*:input:min',  this).each(function(i,e) { $(e).rules('add', { min:    { depends: no_nr, param: e.getAttribute('min') } }); });
    $('*:input:max',  this).each(function(i,e) { $(e).rules('add', { max:    { depends: no_nr, param: e.getAttribute('max') } }); });
    $('*:input:date[data-required~="type=visit_date"]', this).each(function(i,e) { $(e).rules('add', { required_visit_date: true }); });
    $('*:input:text[data-required~="type=year_month"]', this).each(function(i,e) { $(e).rules('add', { required_year_month: { depends: no_nr } }); });

    $('*:input:required', this).each(function(i,e) {
      var container = get_validation_container_for($(e));
      var notice = add_notice(container);
      notice.removeAttr('title');
      container.removeClass('invalid').addClass('valid');
    });
  }
});

