//jQuery.noConflict();

ANIMATION_SPEED = 150; // milliseconds
FRIDGE_ENTRY_PREFIX = '#fridge-entry-';
FRIDGE_ENTRY_REGEX = /fridge-entry-(\d+)/;

FRIDGE_ENTRY_DETAILS_PREFIX = '#fridge-entry-details-';
FRIDGE_ENTRY_DETAILS_REGEX = /fridge-entry-details-(\d+)/;

jQuery( document ).ready( function() {
    init_collapser_lists();
    init_fridge_list();
    init_switcher_panes();
    
    call_anchor_method();

    autofocus();
})

// only functions below
function autofocus() {
  jQuery( '.autofocus' ).focus();
}

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
  )
  jQuery( '.fridge_list tr.summary_container' ).click(
    function() {
      var entry = jQuery( this );
      var details = get_details( entry );
      entry.hasClass( 'active' ) ? hide_fridge_details( entry, details ) : show_fridge_details( entry, details );
      return false;
    }
  )
  jQuery( '.fridge_list tr.details_container .cancel' ).click(
    function() {
      var details = jQuery( this ).closest( '.details_container' );
      var entry = get_entry( details );
      hide_fridge_details( entry, details.find( '.content' ));
      return false;
    }
  )
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
