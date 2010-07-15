// HTML5 input pseudo selectors
// Copyright (c) 2009, Mike Taylor, http://miketaylr.com
// MIT Licensed: http://www.opensource.org/licenses/mit-license.php

// USAGE: $(':search').whatever(); OR $(':input:search').whatever()
// selects all <input type="search"> elements, etc.

// Thanks to Paul Irish and Ben Alman for non-medicated feedback!
// And thanks again to Paul Irish for making it loopier.

// Rather than just function(elem){return type === "foo"}
// we use elem.getAttribute("foo") because unknown input types are
// treated as type=text
(function($){
  $.each('search tel url email datetime date month week time datetime-local number range color'.split(' '),function(i,type){
      $.expr[":"][type] = function(elem){
          return elem.getAttribute("type") === type;
      };
  });
})(jQuery);
