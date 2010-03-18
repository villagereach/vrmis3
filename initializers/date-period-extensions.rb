class Fixnum
  def date_periods
    ((self * 1.months) / 1.month).months
  end
  
  alias_method :date_period, :date_periods
end
  
class Date
  def self.date_periods_per_year
    12
  end
  
  def self.from_date_period(str)
    parse(str + '-01') rescue parse(str)
  end

  def self.to_date_period_format
    '%Y-%m'
  end
  
  def to_date_period
    strftime(self.class.to_date_period_format)
  end
  
  def end_of_date_period
    end_of_month
  end
  
  def beginning_of_date_period
    beginning_of_month
  end
end

class Time
  def to_date_period
    to_date.to_date_period
  end
end
