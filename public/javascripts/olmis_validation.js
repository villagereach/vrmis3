(function($){
  $.each('min max required required_unless_nr'.split(' '),function(i,type){
    $.expr[":"][type] = function(elem){
        return typeof(elem.getAttribute(type)) == 'string';
    };
  });
})(jQuery);

function validateRequiredUnlessNr(value, element) {
  if($('#'+element.getAttribute('required_unless_nr'), $(element.parentNode)).attr('checked'))
    return true
  else
    return $.validator.methods.required.call(this, value, element) 
}

function validateRequiredRadio(value, element) { 
  var btns = $('*[name='+element.name+']', $(element.parentNode)).filter(function(i) { return this.checked; }); 
  return (btns.length > 0);
}

function show_errors(errorMap, errorList) {
  for (var k in errorMap) {
    if(k) {
      var container = $('*:input[name='+k+']').parent();
      var notice = $('.notice', container);
      if (notice.length == 0) {
        container.append('<span class="notice"></span>');
        notice = $('.notice', container);
      }
      notice.attr('title', errorMap[k]);
      container.addClass('error');
    }
  }
  this.validElements().each(function(i,e) { 
    if (errorMap[e.name] == null)
      $(e.parentNode).removeClass('error'); 
  })
}

$.validator.addMethod('required_unless_nr', validateRequiredUnlessNr, $.validator.messages.required);
$.validator.addMethod('required_radio',     validateRequiredRadio, $.validator.messages.required);

$.extend($.fn, {
  setupValidation: function() {
    this.validate( {
      onkeyup: false,
      showErrors: show_errors
    } );

    $('*:input:text:required',  this).each(function(i,e) { $(e).rules('add', { required: true });                 });
    $('*:input:radio:required', this).each(function(i,e) { $(e).rules('add', { required_radio: true });           });
    $('*:input:text:required_unless_nr', this).each(function(i,e) { $(e).rules('add', { required_unless_nr: true });   });
    $('*:number',               this).each(function(i,e) { $(e).rules('add', { digits: true });               });
    $('*:input:min',            this).each(function(i,e) { $(e).rules('add', { min: e.getAttribute('min') } ) });
    $('*:input:max',            this).each(function(i,e) { $(e).rules('add', { max: e.getAttribute('max') } ) });;
    $('*:input:date',           this).each(function(i,e) { $(e).rules('add', { date: true } );                });
  }
});

