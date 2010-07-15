function select_data() {
  var visible = (selected_values.delivery_zone > '' &&
                 selected_values.visit_date_period > '');
  
  $(selected_values).attr('visit_period_selected', visible);

  $('*[show_if_selected]').each(function(i,e) {
    if (selected_values[$(e).attr('show_if_selected')])
      $(e).show();
    else
      $(e).hide();
  });

  $('*[show_unless_selected]').each(function(i,e) {
    if (selected_values[$(e).attr('show_unless_selected')])
      $(e).hide();
    else
      $(e).show();
  });
}

$.fn.setup_selected_values = function() {
  for (var x in selected_values) {
    $(".selected_" + x).linkFrom("html", selected_values, x);
    
    $(".selected_" + x + "_name").linkFrom(
      "html", 
      selected_values, 
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
};

$(function() {
  $("#access_code", this).linkFrom("val", selected_values, "access_code").linkTo("val", selected_values, "access_code");
  $("#dz_selector", this).linkFrom("val", selected_values, "delivery_zone").linkTo("val", selected_values, "delivery_zone");
  $("#vdp_selector", this).linkFrom("val", selected_values, "visit_date_period").linkTo("val", selected_values, "visit_date_period");
  
  data_instance.visit_date_periods = get_available_visit_date_periods().map(function(e) { return { name: e[1], code: e[0] }; });

  $(document).setup_selected_values();
  select_data();
  $(selected_values).attrChange(select_data)
  
  $("#dz_selector", this).html($.tmpl($("#selector_tmpl").html(), {data: data_instance.delivery_zones}));
  $("#vdp_selector", this).html($.tmpl($("#selector_tmpl").html(), {data: data_instance.visit_date_periods}));

  autofocus();
});

