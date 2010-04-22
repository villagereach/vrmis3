function AutoevalHealthCenter(code) {
  var h = localStorage[code + '/visit-history'];
  this.history = JSON.parse(h || '{}');
  this.code = code;

  this.update_visits();
  this.update_stockouts();
}

AutoevalHealthCenter.prototype = {
  statements: function() {
    if (!this.statement_data) {
      this.statement_data = this.not_recently_visited().
        concat(this.excessive_interval()).
        concat(this.insufficient_deliveries()).
        concat(this.stockouts_this_month());
    }
    return this.statement_data;
  },

  /* statement definitions */

  not_recently_visited: function() {
    var ok = this.most_recent_ok_visit();
    if (ok > 0) {
      var age = Math.floor(ms_to_days(new Date().getTime() - ok) / 30); //TODO: Accurate month calculations

      if (age >= AutoevalData.excessive_months_since_last_visit)
        return [I18n.t('reports.autoeval.not_recently_visited', { months: age })]
    }
    return [];
  },

  excessive_interval: function() {
    var n = this.visits.length;
    if (n > 1 && this.visits[n-1][0] == AutoevalData.current_date_period) {
      var interval = ms_to_days(Date.parse(this.visits[n-1][1]) - Date.parse(this.visits[n-2][1]));
      if(interval >= AutoevalData.excessive_days_between_visits)
        return [I18n.t('reports.autoeval.excessive_interval', { days: interval })]
    }
    return [];
  },

  stockouts_this_month: function() {
    var n = this.visits.length;
    if(n > 0) {
      var dp = this.visits[n-1][0]
      var existing = this.existing[dp];
      var products = {};

      for (var x in existing) {
        products[AutoevalData.products_by_package[x]] =
          (products[AutoevalData.products_by_package[x]] || 0) + existing[x];
      }

      var stockouts = [];
      for (var x in products) {
        if (products[x] == 0)
          stockouts.push(x);
      }

      if(stockouts.length > 0) {
        stockouts.sort(function(a,b) { return AutoevalData.product_names.indexOf(a) - AutoevalData.product_names.indexOf(b) });
        return [I18n.t('reports.autoeval.stockouts_this_month', {
            date: I18n.l(Date.from_date_period(dp), { format: 'short_month_of_year' }),
            product: stockouts.map(function(x) { return I18n.t('activerecord.attributes.product.' + x) }).join(", ")
        })];
      }
    }
    return [];
  },

  insufficient_deliveries: function() {
    var n = this.visits.length;
    if(n > 1) {
      var dp = this.visits[n-1][0];
      var pp = this.visits[n-2][0];
      var packages = [];

      for(var x in AutoevalData.ideal_stock_amounts[this.code]) {
        if ((this.delivered[dp] && this.delivered[dp][x] && this.delivered[dp][x] < AutoevalData.ideal_stock_amounts[this.code][x]) &&
            (this.delivered[pp] && this.delivered[pp][x] && this.delivered[pp][x] < AutoevalData.ideal_stock_amounts[this.code][x])
          ) {
          packages.push(x);
        }
      }

      if(packages.length > 0) {
        packages.sort(function(a,b) { return AutoevalData.package_codes.indexOf(a) - AutoevalData.package_codes.indexOf(b) });
        return [I18n.t('reports.autoeval.insufficient_deliveries', {
            product: packages.map(function(x) { return I18n.t('activerecord.attributes.package.' + x) }).join(", ")
          })];
      }
    }
    return [];
  },

  /* utility functions */

  most_recent_ok_visit: function() {
    var date = 0;

    if (this.visits.length > 0)
      date = Date.parse(this.visits[this.visits.length-1][1]);

    if (this.excusable_non_visits.length > 0) {
      var excusable_date = date_period_to_ms(this.excusable_non_visits[this.excusable_non_visits.length-1])
      if (excusable_date > date)
        date = excusable_date;
    }

    return date;
  },

  update_stockouts: function() {
    this.existing = AutoevalData.existing_inventory[this.code] || [];
    this.delivered = AutoevalData.delivered_inventory[this.code] || [];

    for (var dp in this.history) {
      var dp_history = this.history[dp] || [];

      this.existing[dp] = {};
      this.delivered[dp] = {};

      for (var pi = 0; pi < dp_history.existing.length; pi++) {
        this.existing[dp][dp_history.existing[pi][0]] = dp_history.existing[pi][1];
      }

      for (var pi = 0; pi < dp_history.delivered.length; pi++) {
        this.delivered[dp][dp_history.delivered[pi][0]] = dp_history.delivered[pi][1];
      }
    }
  },

  update_visits: function() {
    // visits here is an array of pairs, where the first is the date period identifier and the last is the visit date.
    // excusable_non_visits is just an array of date periods.

    this.visits = [];
    this.excusable_non_visits = [];

    if (AutoevalData.visits[this.code])
      for (var dp in AutoevalData.visits[this.code]) {
        if (!this.history[dp])
          this.visits.push([dp, AutoevalData.visits[this.code][dp]]);
      }

    if (AutoevalData.excusable_non_visits[this.code])
      for (var dp in AutoevalData.excusable_non_visits[this.code]) {
        if (!this.history[dp])
          this.excusable_non_visits.push(dp);
      }

    for (var dp in this.history) {
      var visit = this.history[dp].visit;
      if (visit.match(/^\d+-\d+-\d+$/))
        this.visits.push([dp, visit]);
      else if (AutoevalData.excusable_non_visit_reasons.indexOf(visit) > 0)
        this.excusable_non_visits.push(dp);
    }

    this.visits.sort(function(a,b) { if (a[1] < b[1]) return -1; else if (a[1] == b[1]) return 0; else return 1; });
    this.excusable_non_visits.sort();
  }
};

jQuery(document).ready(
  function() {
    var list = jQuery('#health_centers');

    AutoevalData.province_names.forEach(function(province) {
      list.append('<h4>'+province+'</h4>');
      var div = jQuery(document.createElement('div'));
      var prolist = jQuery(document.createElement('ul'));
      prolist.attr('id', province);
      
      AutoevalData.provinces[province].forEach(function(d) { 
        prolist.append('<li><a href="#'+d+'" id="link_'+d+'">'+d+'</a></li>');
      });

      div.append(prolist);
      list.append(div);
    });

    jQuery('#health_centers > div > ul > li > a').click(function(ev) {
      var dist = this.getAttribute('href').replace('#','');

      jQuery('#autoeval').html('<h2>'+I18n.t('reports.autoeval.header', { name: dist }) + '</h2>')

      for (var hc=0; hc < AutoevalData.districts[dist].length; hc++) {
        var aev = new AutoevalHealthCenter(AutoevalData.districts[dist][hc]);
        var statements = aev.statements().map(function(s) { return '<li>' + s + '</li>' }).join("\n");
        if (statements != "")
          jQuery('#autoeval').append('<h3>' + AutoevalData.hc_names[AutoevalData.districts[dist][hc]] + '</h3><ul>' + statements + '</ul>');
      }
    });

    jQuery('#health_centers').accordion({ header: 'h4' });
});

