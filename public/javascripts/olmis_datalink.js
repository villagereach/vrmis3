var olmis_instance = {};

function select_data() {
  var visible = (data_instance.selected_values.delivery_zone > '' && 
     data_instance.selected_values.field_coordinator > '' &&
     data_instance.selected_values.visit_date_period > '');
  
  $(data_instance.selected_values).attr('visit_period_selected', visible);

  $(".selected_date_period").html(data_instance.selected_values.visit_date_period);
  $(".selected_delivery_zone").html(data_instance.selected_values.delivery_zone);
  
  if(visible)
    $('#select_location').show()
  else
    $('#select_location').hide()
}

$(document).ready(function() {
  $("#access_code", this).linkBoth("val", data_instance.selected_values, "access_code");
  
  $("#dz_selector", this).linkBoth("val", data_instance.selected_values, "delivery_zone");
  $("#fc_selector", this).linkBoth("val", data_instance.selected_values, "field_coordinator");
  $("#vdp_selector", this).linkBoth("val", data_instance.selected_values, "visit_date_period");

  select_data();
  $(data_instance.selected_values).attrChange(select_data)
  $(data_instance.selected_values).attrChange(select_data)
  $(data_instance.selected_values).attrChange(select_data)
  
  $("#dz_selector", this).html($.tmpl($("#selector_tmpl").html(), {data: data_instance.delivery_zones}));
  $("#fc_selector", this).html($.tmpl($("#selector_tmpl").html(), {data: data_instance.field_coordinators}));
  
  months = get_available_visit_months().map(function(e) { return { name: e[1], code: e[0] }; });
  $("#vdp_selector", this).html($.tmpl($("#selector_tmpl").html(), {data: months}));
});

