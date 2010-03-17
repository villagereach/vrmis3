# == Schema Information
# Schema version: 20100127014005
#
# Table name: target_percentages
#
#  id               :integer(4)      not null, primary key
#  name             :string(255)     not null
#  percentage       :decimal(4, 2)   default(0.0), not null
#  stat_tally_klass :string(255)     not null
#  created_at       :datetime
#  updated_at       :datetime
#

class TargetPercentage < ActiveRecord::Base
  unloadable

  has_and_belongs_to_many :descriptive_values

  validates_presence_of :stat_tally_klass
  validates_numericality_of :percentage

  include Comparable
  def <=>(other)
    label <=> other.label
  end
    
  def validate

    begin
      klass_category_codes = tally._categories.map(&:last) 
    rescue 
      errors.add(:stat_tally_klass, "must be a StatTally class name")
      klass_category_codes = []
    end
    
    descriptive_values.each do |dv|
      unless klass_category_codes.include? dv.descriptive_category.code
        errors.add(dv.label, " is not a descriptor for #{stat_tally_klass}")
      end
    end
    
    (changes.keys - ['percentage']).each do |k|
      errors.add(k, " is a read-only value") unless new_record? 
    end
  end
  
  def coverage_and_total(location, date_period)
    location = [location].flatten.map(&:health_centers).flatten
    
    vaccinations, periods, population, scaled_population = total_vaccinations(location, date_period)
    if population.to_f > 0 && vaccinations.to_f > 0
      [100.0 * vaccinations / (scaled_population * percentage), vaccinations, population]
    else
      []
    end
  end
  
  def coverage(location, date_period)
    ct = coverage_and_total(location, date_period) 
    ct[0]
  end

  def label
    I18n.t("TargetPercentage.#{code}")
  end
  alias_method :name, :label
  
  def tally_subquery(health_centers, date_periods)
    conditions = tally.send(:sanitize_sql_for_conditions, tally_columns_to_relevant_values.merge({ :health_center_id => health_centers, :date_period => date_periods }) )

    "SELECT SUM(value) as value, health_center_id, date_period FROM #{stat_tally_klass.tableize} WHERE #{conditions} AND value IS NOT NULL GROUP BY health_center_id, date_period"
  end
  
  private
  
  def tally
    stat_tally_klass.constantize
  end

  def total_vaccinations(location, date_period)
    conditions = tally.send(:sanitize_sql_for_conditions,
      tally_columns_to_relevant_values.
        merge({ "health_center_id" => location, "date_period" => date_period }))

    f = connection.select_all(<<-SQL.squish).first
      SELECT sum(value) as value, sum(periods) as total_periods, sum(population * periods / #{ Date.date_periods_per_year }) as scaled_population, sum(population) as population
      FROM health_centers 
      INNER JOIN administrative_areas ON administrative_area_id = administrative_areas.id
      INNER JOIN (select health_center_id, sum(value) as value, count(distinct date_period) as periods 
                    FROM #{stat_tally_klass.tableize} WHERE #{conditions} AND value IS NOT NULL GROUP BY health_center_id) x
              ON health_center_id = health_centers.id 
    SQL

    return f['value'].to_i, f['total_periods'].to_i, f['population'].to_i, f['scaled_population'].to_f if f 
  end

  def tally_columns_to_relevant_values
    Hash[*categories_to_columns.map { |cat, col| [col, categories_to_values[cat]] }.inject { |a,b| a + b }]
  end
  
  def categories_to_values
    @cv ||= Hash[*descriptive_values.group_by(&:descriptive_category_code).inject { |a,b| a + b }]
  end
  
  def categories_to_columns
    @cc ||= Hash[*categories_to_values.keys.
      map { |dc| [dc, tally._categories.detect { |tc| tc.last == dc }.first.to_s + '_id' ] }.flatten]
  end  
end


