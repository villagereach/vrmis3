# == Schema Information
# Schema version: 20100419182754
#
# Table name: stock_card_statuses
#
#  id                     :integer(4)      not null, primary key
#  stock_card_id          :integer(4)      not null
#  stock_room_id          :integer(4)      not null
#  health_center_visit_id :integer(4)      not null
#  have                   :boolean(1)
#  used_correctly         :boolean(1)
#  reported_at            :date
#  created_at             :datetime
#  updated_at             :datetime
#

class StockCardStatus < ActiveRecord::Base
  include BasicModelSecurity

  belongs_to :stock_card
  belongs_to :stock_room
  belongs_to :health_center_visit

  validates_presence_of :stock_card_id
  validates_presence_of :stock_room_id
  validates_presence_of :health_center_visit_id

  #validates_inclusion_of :have,           :in => [ true, false ]
  #validates_inclusion_of :used_correctly, :in => [ true, false ], :if => lambda {|r| r.have?}

  def date
    reported_at.to_date
  end

  def date=(d)
    self.reported_at = d.to_date + 12.hours
  end
  
  def self.screens
    ['stock_cards']
  end  

  def self.process_data_submission(visit, params)
    errors = {}
    stock_card_statuses = visit.find_or_initialize_stock_card_statuses

    params[:stock_card_status].each do |key, values|
      record = stock_card_statuses.detect{|s| s.stock_card_code == key}

      # Skip if no data entered for a new item
      next if record.new_record? && values["have"].blank? && values["used_correctly"].blank?

      db_values = values.inject({}){|hash,(key,value)| hash[key] = value == "true" || (value == "false" ? false : nil) ; hash }

      record.date = visit.date
      record.update_attributes(db_values)
      unless record.errors.empty?
        errors[key] = record.errors
      end
    end
    
    errors
  end
  
  def self.progress_query(date_periods)
    stock_cards = StockCard.count

    <<-TALLY
    select health_center_visits.id as id,
      health_center_visits.visit_month as date_period,
      'stock_cards' as screen,
      #{stock_cards}                                                        + sum(case when stock_card_statuses.have = 1 then 1 else 0 end) as expected_entries,
      sum(case when stock_card_statuses.have IS NOT NULL then 1 else 0 end) + sum(case when stock_card_statuses.have = 1 AND stock_card_statuses.used_correctly IS NOT NULL then 1 else 0 end) as entries
    from health_center_visits
    left join stock_card_statuses on 
      stock_card_statuses.health_center_visit_id = health_center_visits.id
    where health_center_visits.visit_month in (#{date_periods})
    group by health_center_visits.id
    TALLY
  end

end


