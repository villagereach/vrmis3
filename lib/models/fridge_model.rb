# == Schema Information
# Schema version: 20100419182754
#
# Table name: fridge_models
#
#  id           :integer(4)      not null, primary key
#  capacity     :decimal(10, 2)  default(0.0), not null
#  code         :string(255)     not null
#  description  :text            default(""), not null
#  power_source :string(255)     default(""), not null
#  created_at   :datetime
#  updated_at   :datetime
#

class FridgeModel < ActiveRecord::Base
  include BasicModelSecurity
  referenced_by :code
  has_many :fridges
  
  def self.options_for_select
    all(:order => 'code').map { |f| [f.code, f.id] }
  end

  def self.power_sources
    %w(Electric Propane Solar).freeze
  end

  def to_label
    description
  end

end


