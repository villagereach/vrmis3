# == Schema Information
# Schema version: 20100127014005
#
# Table name: fridge_statuses
#
#  id          :integer(4)      not null, primary key
#  fridge_id   :integer(4)      not null
#  user_id     :integer(4)      not null
#  status_code :string(255)     default(""), not null
#  temperature :integer(4)
#  reported_at :datetime        not null
#  notes       :text
#  created_at  :datetime
#  updated_at  :datetime
#

class FridgeStatus < ActiveRecord::Base
  include BasicModelSecurity

  belongs_to :fridge
  belongs_to :user, :foreign_key => 'user_id', :class_name => 'User'
                           
  def nr
    !new_record? && temperature.nil?
  end

  validates_numericality_of :temperature, :only_integer => true, :allow_nil => true
  #validates_inclusion_of    :temperature, :in => (2..8), :if => lambda{|r| r.status_code == 'OK'}, :message => :working_temp_range, :allow_nil => true

  def reported_by
    user                                                                                     
  end

  validates_presence_of :date, :status_code

  named_scope :health_center, lambda { |hc| 
    { 
      :include => { :fridge => { :stock_room => :health_center } },
      :conditions => { 'health_centers.id' => hc }
    }
  }

  named_scope :fridge, lambda{|f|
    {
      :include => { :fridge => { :stock_room => :health_center } },
      :conditions => { 'fridges.id' => f }
    }
  }

  named_scope :in_delivery_zone, lambda{|dz|
    delivery_zone_id = dz.is_a?(DeliveryZone) ? dz.id : dz.to_i
    {
      :include => { :fridge => { :stock_room => :health_center } },
      :conditions => [ 'health_centers.delivery_zone_id = ?', delivery_zone_id ]
    }
  }

  named_scope :in_district, lambda{|d|
    district_id = d.is_a?(District) ? d.id : d.to_i
    {
      :include => { :fridge => { :stock_room => :health_center } },
      :conditions => [ (<<-SQL).squish, district_id ]
        health_centers.administrative_area_id IN (SELECT id FROM administrative_areas WHERE parent_id = ?)
      SQL
    }
  }

  named_scope :in_province, lambda{|p|
    province_id = p.is_a?(Province) ? p.id : p.to_i
    {
      :include => { :fridge => { :stock_room => :health_center } },
      :conditions => [ (<<-SQL).squish, 'District', province_id ]
        health_centers.administrative_area_id IN (SELECT hc.id
                                                    FROM administrative_areas hc
                                                         INNER JOIN administrative_areas dst 
                                                         ON hc.parent_id = dst.id AND dst.type = ?
                                                   WHERE dst.parent_id = ?)
      SQL
    }
  }

  def self.status_codes
    Olmis.configuration['fridge_statuses']
  end

  def self.status_options
    status_codes.collect{|code| [ I18n.t("FridgeStatus.#{code}"), code ]}
  end

  def self.not_ok_status_options
    self.status_options.reject{|human,code| code=='OK'}
  end

  def to_label
    date_str = (if Date.today - 1.year > date 
                  I18n.l(date, :format => :long)
                else 
                  I18n.l(date, :format => :short) 
                end)
    
    if other_problem.blank?
      "#{ i18n_status_code } #{date_str}"
    else
      "#{ i18n_status_code } (#{ other_problem }) #{ date_str }"
    end
  end                                                     

  def urgent?
    # TODO: Adjust this list as required
    (FridgeStatus.status_codes - ['OK']).include?(status_code)
  end
  
  def i18n_status_code
    I18n.t("FridgeStatus.#{status_code}", :default => status_code)
  end
  
  def status_category
    case status_code 
    when 'BROKE' then 'red'
    when 'OK'    then 'green'
    else              'yellow'
    end
  end
  
  def self.statuses_in_category(category)
    case category
    when 'red' then ['BROKE']
    when 'green' then ['OK']
    else status_codes - ['BROKE', 'OK'] + ['NO STATUS']
    end
  end
  
  def date
    reported_at.to_date
  end
  
  def date=(d)
    self.reported_at = d.to_date + 12.hours
  end

  def self.screens
    ['cold_chain']
  end
  
  def self.xforms_to_params(xml)
    Hash[
      *xml.xpath('/olmis/hcvisit/visit/cold_chain/fridges/fridge').map do |fridge|
        [
          fridge['code'].to_s, 
          {
            "past_problem" => fridge['past_problem'].to_s,
            "temperature" => fridge['temp'].to_s,
            "state" => fridge['state'].to_s,
            "problem" => fridge['problem'].to_s,
            "other_problem" => fridge['other_problem'].to_s
          }
        ]
      end.flatten_once
    ]
  end

  def self.odk_to_params(xml)
    Hash[
      *xml.xpath("/olmis/location/fridges/*/*").map do |fridge|
        [
          fridge['code'].to_s,
          {
            "past_problem"  =>  fridge.xpath('./past_problem').text,
            "temperature"   =>          fridge.xpath('./temp').text,
            "state"         =>         fridge.xpath('./state').text,
            "problem"       =>       fridge.xpath('./problem').text,
            "other_problem" => fridge.xpath('./other_problem').text
          }
        ]
      end.flatten_once
    ]
  end

  def self.process_data_submission(visit, params)
    errors = {}

    fridge_statuses = visit.find_or_initialize_fridge_statuses

    params[:fridge_status].each do |key, values|
      # Skip if no data entered for this fridge
      next if values.values.all?(&:blank?)

      if record = fridge_statuses.detect{|fs| fs.fridge_code == key.to_s }
        db_values = {
          :past_problem  => values["past_problem"] == "true" || (values["past_problem"] == "false" ? false : nil),
          :temperature   => values["temperature"].blank? ? nil : values["temperature"].to_i,
          :status_code   => values["state"] == "OK" ? "OK" : values["state"] == "nr" ? nil : values["problem"].join(' '),
          :other_problem => values["state"] == "problem" && values["problem"].include?("OTHER") ? values["other_problem"] : nil
        }
        record.update_attributes(db_values)
        unless record.errors.empty?
          errors[key] = record.errors
        end
      else
        # TODO: The fridge code changed; should this be possible in the online form?
      end
    end
    
    errors
  end    
  
  def self.progress_query(date_periods)
    <<-CC
      select health_center_visits.id as id, 
        'cold_chain' as screen,
        health_center_visits.visit_month as date_period,
        count(distinct fridges.id) as expected_entries,
        count(distinct fridge_statuses.id) as entries
      from health_center_visits 
        left join health_centers on health_centers.id = health_center_id
        left join stock_rooms on stock_rooms.id = health_centers.stock_room_id
        left join fridges on fridges.stock_room_id = stock_rooms.id
        left join fridge_statuses 
          on fridge_statuses.fridge_id = fridges.id
          and date(fridge_statuses.reported_at) = health_center_visits.visited_at
          and fridge_statuses.user_id = health_center_visits.user_id
        where health_center_visits.visit_month in (#{date_periods})
      group by health_center_visits.id 
    CC
  end
  
  report_column :fridge_code,          :sql_sort => 'fridges.code', :header => "headers.fridge_code", :type => :link, :data_proc => lambda { |s| [s.fridge_code, s.fridge ] }
  report_column :fridge_health_center, :sql_sort => 'administrative_areas.name', :header => "headers.health_center", :data_proc => lambda { |s| [s.fridge.stock_room.administrative_area.name] }
  report_column :fridge_district,      :sortable => false, :header => "headers.district",      :data_proc => lambda { |s| [s.fridge.stock_room.administrative_area.district.name] }
  report_column :status_code,          :sql_sort => 'fridge_statuses.status_code', :header => "headers.status", :data_proc => :i18n_status_code
  report_column :temperature,          :sql_sort => 'fridge_statuses.temperature', :header => "headers.temperature", :type => :int
  report_column :date,                 :sql_sort => 'fridge_statuses.reported_at', :header => "headers.date", :type => :date, :data_proc => :reported_at
  report_column :time,                 :sql_sort => 'fridge_statuses.reported_at', :header => "headers.time", :type => :datetime, :data_proc => :reported_at
  report_column :other_problem,        :sortable => false, :header => "headers.other_problem"
  report_column :reported_by,          :sql_sort => 'users.name', :header => "headers.reported_by", :data_proc => lambda { |s| s.user_name }

end
