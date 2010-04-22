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


