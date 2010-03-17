# == Schema Information
# Schema version: 20100127014005
#
# Table name: street_addresses
#
#  id             :integer(4)      not null, primary key
#  address1       :string(255)     default(""), not null
#  address2       :string(255)     default(""), not null
#  city           :string(255)     default(""), not null
#  postal_code    :string(255)     default(""), not null
#  notes          :text            default(""), not null
#  latitude       :float
#  longitude      :float
#  addressed_id   :integer(4)
#  addressed_type :string(255)
#  created_at     :datetime
#  updated_at     :datetime
#

class StreetAddress < ActiveRecord::Base
  unloadable

  belongs_to :addressed, :polymorphic => true
  
  validates_numericality_of :latitude,  :allow_nil => true
  validates_numericality_of :longitude, :allow_nil => true
  
  def to_s
    %w(address1 address2 city postal_code).map { |s| send(s) }.reject(&:blank?).join(" / ")
  end
  alias_method :to_label, :to_s
  
  def centroid
    [latitude, longitude]
  end
end


