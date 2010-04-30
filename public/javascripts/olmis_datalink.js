var olmis_instance = {};

function select_data() {
  var visible = (data_instance.selected_values.delivery_zone > '' && 
     data_instance.selected_values.field_coordinator > '' &&
     data_instance.selected_values.visit_date_period > '');
  
  $(data_instance.selected_values).attr('visit_period_selected', visible);

  $('*[show_if_selected]').each(function(i,e) {
      if(data_instance.selected_values[$(e).attr('show_if_selected')])
      $(e).show()
    else
      $(e).hide()
  });
}

$(document).ready(function() {
  $("#access_code", this).linkBoth("val", data_instance.selected_values, "access_code");
  
  $("#dz_selector", this).linkBoth("val", data_instance.selected_values, "delivery_zone");
  $("#fc_selector", this).linkBoth("val", data_instance.selected_values, "field_coordinator");
  $("#vdp_selector", this).linkBoth("val", data_instance.selected_values, "visit_date_period");

  for (var x in data_instance.selected_values) {
    $(".selected_" + x).linkFrom("html", data_instance.selected_values, x);
    
    $(".selected_" + x + "_name").linkFrom(
      "html", 
      data_instance.selected_values, 
      x, 
      (function(variable) { 
        return function(v) { 
          if (v && data_instance[variable + "s"]) {
            var vv = $(data_instance[variable + "s"]).filter(function() { return this.code == v });
            if (vv.length > 0)
              return vv[0].name
          }
          return "";
        };
      })(x)
    );
  }
  
  select_data();
  $(data_instance.selected_values).attrChange(select_data)
  
  $("#dz_selector", this).html($.tmpl($("#selector_tmpl").html(), {data: data_instance.delivery_zones}));
  $("#fc_selector", this).html($.tmpl($("#selector_tmpl").html(), {data: data_instance.field_coordinators}));
  
  months = get_available_visit_months().map(function(e) { return { name: e[1], code: e[0] }; });
  $("#vdp_selector", this).html($.tmpl($("#selector_tmpl").html(), {data: months}));

  autofocus();
});

