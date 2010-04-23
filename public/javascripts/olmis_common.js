// only functions below
jQuery.fn.findInput = function() {
  return this.map(function(i, e) {
    if (e.nodeName == 'INPUT')
      return e;
    else
      return jQuery('*:input', jQuery(e))[0]
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

  jQuery(id).
    datepicker(jQuery.extend(js_datepicker_default_options,
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

function init_expression_fields() {
  jQuery('input[expression]').each(function(i,field) {
    // every field starts with an alpha and contains no spaces
    var tokens = jQuery(field.getAttribute('expression').split(/([A-Za-z][^ \(\)]+)/))

    var suffix = field.getAttribute('suffix').toString();
    
    if(tokens.length % 2 == 0)
      tokens.push('')

    var fields = jQuery(jQuery.grep(tokens.map(function(i, t) { return(i % 2 == 1 ? t : '') }),
                                    function(t, i) { return t != '' }))

    var expression = jQuery.makeArray(tokens.map(function(i, f) { 
      if(jQuery.inArray(f, fields) > -1)
        return 'parseFloat(0 + jQuery("#' + f + '").findInput().val())'
      else
        return f
    })).join("");
    
    fn = update_calculated_field_function(field, expression, suffix)
 
    jQuery(document).ready(fn);
    
    fields.each(function(i, e) {
      jQuery('#' + e).findInput().change(fn);
    });
  });
}

jQuery( document ).ready( function() {
  init_expression_fields();
});
