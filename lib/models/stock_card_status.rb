# == Schema Information
# Schema version: 20100127014005
#
# Table name: stock_card_statuses
#
#  id                     :integer(4)      not null, primary key
#  stock_card_id          :integer(4)      not null
#  stock_room_id          :integer(4)      not null
#  health_center_visit_id :integer(4)      not null
#  have                   :boolean(1)      not null
#  used_correctly         :boolean(1)
#  created_at             :datetime
#  updated_at             :datetime
#  reported_at            :date
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

end


