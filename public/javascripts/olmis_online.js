//jQuery.noConflict();

ANIMATION_SPEED = 150; // milliseconds
FRIDGE_ENTRY_PREFIX = '#fridge-entry-';
FRIDGE_ENTRY_REGEX = /fridge-entry-(\d+)/;

FRIDGE_ENTRY_DETAILS_PREFIX = '#fridge-entry-details-';
FRIDGE_ENTRY_DETAILS_REGEX = /fridge-entry-details-(\d+)/;

var jqplots={}; 
var table_options={};
  
// {{{ collapser lists
function init_collapser_lists() {
  jQuery( '.collapser_container .collapser' ).children( 'li' ).children( 'span' ).click(
    function() {
      var this_list = jQuery( this ).closest( '.collapser' );
      this_list.hasClass( 'collapser_open' ) ? close_collapser( this_list ) : open_collapser( this_list );
    }
  )
}

function close_all_collapsers() {
  jQuery( '.collapser_container .collapser_open' ).each(
    function() {
      close_collapser( jQuery( this ));
    }
  )
}

function open_collapser( this_list ) {
  close_all_collapsers();
  this_list.addClass( 'collapser_open' );
  this_list.find( 'ul' ).slideDown( ANIMATION_SPEED );
  return false;
}

function close_collapser( this_list ) {
  this_list.removeClass( 'collapser_open' );
  this_list.find( 'ul' ).slideUp( ANIMATION_SPEED );
  return false;
}
// }}} /collapser lists
// {{{ fridge list
function init_fridge_list() {
  jQuery( '.fridge_list tr.summary_container td' ).hover(
      function() { jQuery( this ).parent().addClass( 'hover' ); },
      function() { jQuery( this ).parent().removeClass( 'hover' ); }
  );
  jQuery( '.fridge_list tr.summary_container' ).click(
    function() {
      var entry = jQuery( this );
      var details = get_details( entry );
      entry.hasClass( 'active' ) ? hide_fridge_details( entry, details ) : show_fridge_details( entry, details );
      return false;
    }
  );
  jQuery( '.fridge_list tr.details_container .cancel' ).click(
    function() {
      var details = jQuery( this ).closest( '.details_container' );
      var entry = get_entry( details );
      hide_fridge_details( entry, details.find( '.content' ));
      return false;
    }
  );
  jQuery( '.fridge_list tr.details_container select' ).change(
    function() {
      // Show or hide the following DT/DD pair
      if (jQuery(this).val() == 'OTHER') {
        jQuery(this).closest('dd').next().show().next().show();
      } else {
        jQuery(this).closest('dd').next().hide().next().hide();
      }
      return false;
    }
  );
}

function get_entry( details ) {
  var id = details.attr( 'id' ).match( FRIDGE_ENTRY_DETAILS_REGEX )[ 1 ];
  var entry = jQuery( FRIDGE_ENTRY_PREFIX + id );
  return entry;
}

function get_details( entry ) {
  var id = entry.attr( 'id' ).match( FRIDGE_ENTRY_REGEX )[ 1 ];
  var details = jQuery( FRIDGE_ENTRY_DETAILS_PREFIX + id + ' .content' );
  return details;
}

function show_fridge_details( entry, details ) {
  entry.addClass( 'active' );
  details.closest( '.details_container' ).addClass( 'active' );
  details.slideDown( ANIMATION_SPEED );
  return false;
}

function hide_fridge_details( entry, details ) {
  entry.removeClass( 'active' );
  details.closest( '.details_container' ).removeClass( 'active' );
  details.slideUp( ANIMATION_SPEED );
  return false;
}

function show_or_hide_other_fridge_problem(node) {
  if (node.val() == 'OPER') {
    node.parent().next().show().next().show();
  } else {
    node.parent().next().hide().next().hide();
  }
}
// }}} /fridge list
// {{{ switcher panes
function init_switcher_panes() {
  var content_pane = jQuery('.switcher_pane .switcher_pane_content .content');
  var excess = parseInt(content_pane.css('padding-top')) + parseInt(content_pane.css('padding-bottom'));
  content_pane.css('min-height', (jQuery('.switcher_pane .switcher_pane_menu').height() - excess)+'px');
}
// }}} /switcher panes

function call_anchor_method() {  
  // so /visits/2009-11#name loads with the 'name' tab selected
  // should be harmless for links to actual anchors
  // TODO: replace with some superior method
  if(window.location.hash != '') {
    jQuery('a').each(
      function() {
        if (this.href.toString() == window.location.toString())
          jQuery(this).trigger("click");
      })
  }
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
  
  init_collapser_lists();
  init_fridge_list();
  init_switcher_panes();
  
  call_anchor_method();

  autofocus();
  
  setup_error_links();
  setup_datepicker('input.datepicker', { changeMonth: true, changeYear: true, yearRange: '-1:+5' });
});

