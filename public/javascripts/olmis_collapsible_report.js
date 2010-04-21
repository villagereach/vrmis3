var offset_by_name = {};

function present_colgroup(name, identifier) {  
  if (offset_by_name && offset_by_name[identifier] && offset_by_name[identifier][name]) {
    var offsets = offset_by_name[identifier][name]
    
    table = jQuery('#'+identifier+'.report-table')
    tabs = jQuery('.collapsible-table .tabs.'+identifier+' li');
    tabs.removeClass('selected');
    selected = tabs.filter(function(i) { return jQuery(tabs[i]).text() == name; })
    selected.addClass('selected');
    jQuery('a', selected).blur();
    
    header_context = jQuery('thead > tr:last-child', table);
    
    jQuery('tbody td+td+td', table).hide();
    jQuery('th+th+th', header_context).hide();
    for (var x = offsets[0]; x < offsets[1]; x++) {
      jQuery('th:nth-child('+(x+1)+')', header_context).show();
      jQuery('tbody > tr > td:nth-child('+(x+1)+')', table).show();
    }

  }
}

jQuery(document).ready(  
  function() {
    jQuery(".collapsible-table #table-selector").change(function() {  
        jQuery(".collapsible-table .table-container").hide();
        jQuery(".collapsible-table #table-container-"+jQuery(".collapsible-table #table-selector").val()).show();
    });
    
    jQuery(".collapsible-table .table-container").hide();
    jQuery(".collapsible-table .table-container").slice(0,1).show();
    
    if (jQuery(".collapsible-table .tabs").length > 0) {
      jQuery(".collapsible-table .report-table > thead > tr:first-child").hide();

      jQuery('.collapsible-table .report-table').each(function(i, rt) {
        var offset = 0;
        offset_by_name[rt.id] = {}
        jQuery('th', jQuery('thead > tr:first-child', jQuery(rt))).each(function(i,e) {
          colspan = parseInt(jQuery(e).attr('colspan') || "1")
          offset_by_name[rt.id][jQuery(e).text()] = [offset, offset + colspan];
          offset += colspan;
        });
      });
  
      jQuery(".collapsible-table .tabs li a").bind('click', 
        function(e) { 
          present_colgroup(e.currentTarget.href.replace(/^.*#/, ''), 
            jQuery(e.currentTarget.parentNode.parentNode)[0].className.split(' ')[1]); 
          return false; 
        });
  
      jQuery('.collapsible-table .report-table').each(function(i, rt) {
        present_colgroup(jQuery('.collapsible-table .tabs.'+rt.id+' li:first-child').text(), rt.id);
      });
    }
    
    jQuery(".collapsible-table .report-table > tbody > tr").removeClass("even odd");
    jQuery(".collapsible-table .report-table > tbody > tr.date_period:even").addClass("even");
    jQuery(".collapsible-table .report-table > tbody > tr.province:even").addClass("even");
    jQuery(".collapsible-table .report-table > tbody > tr.delivery_zone:even").addClass("even");
    jQuery(".collapsible-table .report-table > tbody > tr.district:even").addClass("even");
    jQuery(".collapsible-table .report-table > tbody > tr.health_center:even").addClass("even");
    jQuery(".collapsible-table .report-table").treeTable({ clickableNodeNames: true });
  });

