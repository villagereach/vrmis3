$.validateRequired         = function() { };
$.validateRequiredUnlessNr = function() { };
$.validateNumber           = function() { };

$.setupValidation = function() {
  $('*:input',                     this).each(function(i, e) { $(e).attr('validations', []) });
  $('*:input[required]',           this).each(function(i,e) { e.validations.push($.validateRequired) });
  $('*:input[required-unless-nr]', this).each(function(i,e) { e.validations.push($.validateRequiredUnlessNr) });
  $('*:input[type=number]',        this).each(function(i,e) { e.validations.push($.validateNumber) });
};

$(document).ready(function() {
  $(document).setupValidation(); 
});
