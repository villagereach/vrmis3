function indexOf(a, x) { 
  for(i=0; i < a.length; i++) 
    if(a[i] === x) 
      return i 
  return null; 
}

Element.prototype.parentOfType      = function(t) { var p = this; do { p = p.parentNode;      } while (!!p && p.nodeName.toLowerCase() != t.toLowerCase()); return p }
Element.prototype.nextSiblingOfType = function(t) { var p = this; do { p = p.nextSibling;     } while (!!p && p.nodeName.toLowerCase() != t.toLowerCase()); return p }
Element.prototype.prevSiblingOfType = function(t) { var p = this; do { p = p.previousSibling; } while (!!p && p.nodeName.toLowerCase() != t.toLowerCase()); return p }

var input_selector = 'input[type="text"]'

function select_input(i, dir) {
  i.focus();

  switch(dir) {
  case 'left': i.selectionStart = i.selectionEnd = 0; break;
  case 'right': i.selectionStart = i.selectionEnd = i.value.length; break;
  default: 
  }

  return true;
}
  

function moveLeft(t) {
  var td, ptd, input;
  
  if (t.selectionStart != t.selectionEnd || t.selectionStart != 0)
    return false;
  
  if (ptd = td = t.parentOfType('TD')) {
    while (ptd = ptd.prevSiblingOfType('TD')) {
      if (input = jQuery(input_selector, ptd))
        if (input.is(':visible')) 
          return select_input(input[0], 'left')
    }
  }
}

function moveUp(t) {
  var tr, ptr, idx, input;
  if (ptr = tr = t.parentOfType('TR'))
    while (ptr = ptr.prevSiblingOfType('TR')) {
      idx = indexOf(tr.childNodes, t.parentOfType('TD'))
      if (input = jQuery(input_selector, ptr.childNodes[idx]))
        if (input.is(':visible')) 
          return select_input(input[0], 'up')
    }
}

function moveRight(t) {
  var td, ptd, input;

  if (t.selectionStart != t.selectionEnd || t.selectionStart != t.value.length)
    return false;
  
  if (ptd = td = t.parentOfType('TD')) {
    while (ptd = ptd.nextSiblingOfType('TD')) {
      if (input = jQuery(input_selector, ptd))
        if (input.is(':visible'))
          return select_input(input[0], 'right')
    }
  }
}

function moveDown(t) {
  var tr, ptr, idx, input;
  if (ptr = tr = t.parentOfType('TR'))
    while (ptr = ptr.nextSiblingOfType('TR')) {
      idx = indexOf(tr.childNodes, t.parentOfType('TD'))
      if (input = jQuery(input_selector, ptr.childNodes[idx]))
        if (input.is(':visible'))
          return select_input(input[0], 'down')
    }
}

function addEvents() {
  jQuery('table.spreadsheet input').keydown(function(ev) {
    switch(ev.which) {
    case 37: moveLeft(this) ; break;
    case 38: moveUp(this)   ; break;
    case 39: moveRight(this); break;
    case 40: moveDown(this) ; break;
    }
  });
}

jQuery(document).ready(function() { addEvents(); });
