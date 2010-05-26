// only functions below
$.fn.findInput = function() {
  return this.map(function(i, e) {
    if (e.nodeName == 'INPUT')
      return e;
    else
      return $('*:input', $(e))[0]
  });
};

function setup_error_links() {
  $('#error > ul > li > a').each(function(i,e) {
    $(e.getAttribute('href')).addClass('error');
  })
}

function setup_datepicker(id, options) {
  options = options || {}
  js_datepicker_default_options = 
     { 'buttonImage': '/images/icons/silk/calendar_view_month.png',
       'buttonImageOnly': true,
       'gotoCurrent': true,
       'hideIfNoPrevNext': true,
       'showMonthAfterYear': false,
       'showOn': 'both' };

  locale = document.childNodes[1].lang

  region = typeof jQuery.datepicker.regional[locale] === 'object' ? locale : ''

  return jQuery(id).datepicker(jQuery.extend(js_datepicker_default_options,
                                             options,
                                             jQuery.datepicker.regional[region]));
};

function autofocus() {
  jQuery( '.autofocus' ).focus();
}

function update_calculated_field_function(field, expression, suffix) {
  return function() {
    try {
      var v = parseInt(eval(expression));
      jQuery(field).val(isFinite(v) ? (v.toString() + suffix) : ''); 
      jQuery(field).findInput().change();
    } catch (e) {
      alert("Failure: " + expression);
    }
  };
}

$.fn.init_expression_fields = function() {
  $('input[expression]', this).each(function(i,field) {
    // every field starts with an alpha and contains no spaces
    var tokens = $($(field).attr('expression').split(/([A-Za-z][^ \(\)]+)/));
    var suffix = $(field).attr('suffix').toString();
    
    if(tokens.length % 2 == 0)
      tokens.push('')

    var fields = tokens.map(function(i, t) { return(i % 2 == 1 ? t : '') }).
                        filter(function(i) { return this != ''; }); 

    var expression = $.makeArray(tokens.map(function(i, f) { 
      if($.inArray(f, fields) > -1)
        return 'parseFloat(0 + $("#' + f + '").findInput().val())'
      else
        return f
    })).join("");
    
    fn = update_calculated_field_function(field, expression, suffix)
 
    fn;
    
    fields.each(function(i, e) {
      $('#' + e).findInput().change(fn);
    });
  });
}

$(function() { $(document).init_expression_fields(); })
