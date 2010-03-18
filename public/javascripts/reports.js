if (!Array.prototype.forEach) {
  Array.prototype.forEach = function(fun /*, thisp*/) {
    var len = this.length >>> 0;
    if (typeof fun != "function")
      throw new TypeError();

    var thisp = arguments[1];
    for (var i = 0; i < len; i++) {
      if (i in this)
        fun.call(thisp, this[i], i, this);
    }
  };
}

function disable_jqplots(selected, dimension) {
 for (var j in jqplots) {
    var plot = jqplots[j];
    
    if(plot.x_dimension == dimension) {
      points = plot.orig_ticks.map(function(e,i) { return i }).filter(function(e) { return (selected.indexOf(plot.orig_ticks[e]) > -1) }) 
      plot.data =  plot.orig_data.filter(function(e,i) { return points.indexOf(i) > -1 }) 
      plot.axes.xaxis.ticks =  plot.orig_ticks.filter(function(e,i) { return points.indexOf(i) > -1 }) 
    } else if (plot.series_dimension == dimension) {
      for (var s = 0; s < plot.series.length; s++) {
        plot.series[s].show = (selected.indexOf(plot.series[s].label) > -1) 
      }
    }
  }
}

function disable_tables(selected, dimension) {
  for (var t in table_options) {
    var table = table_options[t];
    if(table.rows == dimension) {
      var ctx = jQuery('table.'+t+' > tbody'); 
      var offsets = jQuery.makeArray(jQuery('tr > td:first-child', ctx).map(function(i,e) { if(selected.indexOf(jQuery(e).text()) > -1) return i; else return -1 }));
      jQuery('tr', ctx).hide();
      offsets.forEach(function(i) {
        if (i >= 0) {
          jQuery('tr:nth-child('+(i+1)+')', ctx).show();
        }
      });
    } else if(table.columns == dimension) {
      var ctx = jQuery('table.'+t);
      var offsets = jQuery.makeArray(jQuery('thead > tr:last-child th', ctx).map(function(i,e) { if(selected.indexOf(jQuery(e).text()) > -1) return i; else return -1 }));
      jQuery('tbody > tr > td + td', ctx).hide();
      jQuery('thead > tr:last-child > th + th', ctx).hide();
      offsets.forEach(function(i) {
        if (i >= 0) {
          jQuery('tbody > tr > td:nth-child('+(i+1)+')', ctx).show();
          jQuery('thead > tr:last-child > th:nth-child('+(i+1)+')', ctx).show();
        }
      });
    }
  }
}  

function disable_tabs(selected, dimension) {
  var reselect = [];
  
  jQuery('.tab_graphs > ul > li.'+dimension).each(function(i,e) {
    if (jQuery(e).hasClass('ui-tabs-selected')) {
      reselect.push(e.parentNode.parentNode.id)
    }
    jQuery(e).hide();
  });
  for (var s = 0; s < selected.length; s++) {
    jQuery('.'+dimension+'.' + selected[s].replace(/\W+/g,'_')).show() 
  }
  if (reselect.length > 0 && selected.length > 0) {
    for (var r=0; r < reselect.length; r++) {
      jQuery('#' + reselect[r]).tabs('select', jQuery('#' + reselect[r] + ' li > a:visible:nth-child(1)').attr('href'))
    }
  }
}

function plot_options() {
  for (var x = 0; x < arguments.length; x++) {
    var selected = jQuery.makeArray(jQuery('#options input[name="'+arguments[x]+'"]:checked').map(function(i,e) { return e.value; }));
    disable_jqplots(selected, arguments[x]);
    disable_tables(selected, arguments[x]);
    disable_tabs(selected, arguments[x]);
  }
  
  for (var j in jqplots)
    jqplots[j].redraw();
}

function plot_init() {
  if (table_options) {
    for (var t in table_options) {
      if (table_options[t].area && table_options[t].area != 'health_center_catchment') {
        var option_texts = jQuery('#'+table_options[t].area+'_id > option').map(function(i,o) { return jQuery(o).text() })
        jQuery('.'+t + '> tbody > tr > *:first-child').each(function(i,e) {      
            if (jQuery.inArray(option_texts, jQuery(e).text())) {
              jQuery(e).wrapInner('<a href="#" onclick="drill_down_from_table(\''+table_options[t].area+'\', \''+jQuery(e).text()+'\'); return false;">') 
            }
        });
      }
    }
  }
}

jQuery(document).ready(plot_init);

function drill_down_from_table(level, value) {
  jQuery('#'+level+'_id').val(value);
  jQuery('#'+level+'_id')[0].form.submit();
}

