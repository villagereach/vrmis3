function ms_to_days(m) {
  return Math.floor(m / (86400 * 1000) + 0.5)
}

function date_period_to_ms(dp) {
  var ym = dp.split('-', 2)
  return new Date(ym[0], parseInt(ym[1], 10) - 1, 1);
}

Date.prototype.format = function (string) {  
  string = string.replace(/%b/, I18n.t('date.abbr_month_names')[this.getMonth() + 1], 'g');
  string = string.replace(/%B/, I18n.t('date.month_names')[this.getMonth() + 1]     , 'g');
  string = string.replace(/%d/, ('0' + this.getDate()).substr(-2)                   , 'g');
  string = string.replace(/%m/, ('0' + (this.getMonth() + 1)).substr(-2)            , 'g');
  string = string.replace(/%Y/, this.getFullYear()                                  , 'g');
  return string;
}

Date.from_date_period = function(dp) {
  return new Date(date_period_to_ms(dp));
}

Date.prototype.to_date_period = function() {
  return this.getFullYear() + '-' + ('0' + (this.getMonth() + 1).toString().substr(-2));
}

Date.today = function() {
  var now = new Date();
  return new Date(now.getFullYear(), now.getMonth(), now.getDate());
}

Date.prototype.previous_month = function() {
  var day = this.getDate();
  var month = this.getMonth() - 1;
  var year = this.getFullYear();
  if (month < 0) {
    month = 11;
    year--;
  }
  return new Date(year, month, day);
}

Date.prototype.beginning_of_month = function() {
  return new Date(this.getFullYear(), this.getMonth(), 1);
}

Date.prototype.end_of_month = function() {
  var month = this.getMonth() + 1;
  var year = this.getFullYear();
  if (month > 11) {
    month = 0;
    year++;
  }
  return new Date(year, month, 0);
}
