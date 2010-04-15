jQuery.fn.findInput = function() {
  return this.map(function(i, e) {
    if (e.nodeName == 'INPUT')
      return e;
    else
      return jQuery('*:input', jQuery(e))[0]
  });
};

