# == Schema Information
# Schema version: 20100127014005
#
# Table name: fridges
#
#  id              :integer(4)      not null, primary key
#  code            :string(255)
#  description     :text
#  fridge_model_id :integer(4)      not null
#  created_at      :datetime
#  updated_at      :datetime
#

class Fridge < ActiveRecord::Base
  include BasicModelSecurity
  include ActsAsCoded
  
  referenced_by :code

  belongs_to :fridge_model
  has_many :fridge_statuses, :order => 'fridge_statuses.reported_at desc, fridge_statuses.created_at desc'
    
  validates_presence_of :code
  validates_uniqueness_of :code

  include Comparable
  def <=>(other)
    self.code <=> other.code
  end  
  
  #[PSQL-Note] LIMIT 1 clause does not work in psql
  has_one(:current_status,
          :class_name => 'FridgeStatus',
          :conditions => 'fridge_statuses.id = (SELECT fs2.id FROM fridge_statuses fs2 WHERE fs2.fridge_id = fridge_statuses.fridge_id ORDER BY fs2.reported_at DESC, fs2.created_at DESC LIMIT 1)'
          )

  def self.health_center(hc) 
    # fridge-not-belong-to-HC refactorization ramification:
    # this method now takes in an id, rather than a HealthCenter object 
    stock_room(hc)
  end

  named_scope :stock_room, lambda { |sc| 
    { 
      :include => :current_status,
      :conditions => { 'fridge_statuses.stock_room_id' => sc }
    }
  }

  # Return fridges in the given delivery zone
  named_scope :in_delivery_zone, lambda{|dz|
    delivery_zone_id = dz.is_a?(DeliveryZone) ? dz.id : dz.to_i
    {
      :include => { :current_status => { :stock_room => :health_center } },
      :conditions => [ 'health_centers.delivery_zone_id = ?', delivery_zone_id ]
    }
  }

  # Return fridges in the given province
  def self.in_area_health_centers(locality_key, local_id)
    {      
      :include => { :current_status => { :stock_room => :health_center } },
      :conditions => [ (<<-SQL).squish, local_id ]
        exists (select 1 from #{AdministrativeArea.sql_area_join(false)} where #{locality_key}=? and health_centers.administrative_area_id in (#{AdministrativeArea.sql_area_ids}))
      SQL
    }
  end

  Olmis.area_hierarchy.each do |area|
    named_scope 'in_' + area.tableize.singularize, lambda { |p| Fridge.in_area_health_centers('`' + area.tableize + '`.`id`', p) }
  end

  named_scope :with_status,
  {
    :include => :current_status,
    :conditions => 'fridge_statuses.reported_at IS NOT NULL'
  }

  # Return fridges with a current status that is not OK.
  named_scope :not_ok,
  {
    :include => :current_status,
    :conditions => [ (<<-SQL).squish, 'OK' ]
      (SELECT status_code
         FROM fridge_statuses AS fs
        WHERE fridge_id = fridges.id
          AND status_code IS NOT NULL
        ORDER BY fs.reported_at DESC, fs.created_at DESC
        LIMIT 1) <> ?
    SQL
  }

  # Return fridges with a current status of unknown
  named_scope :unknown_status,
  {
    :include => :current_status,
    :conditions => 'fridge_statuses.status_code IS NULL AND fridge_statuses.reported_at IS NOT NULL'
  }

  # Return fridges that have a non-OK status over +days+ days old
  named_scope :urgent, lambda{|days|
    {
      :include => :current_status,
      :conditions => [ 'fridge_statuses.status_code <> ? AND fridge_statuses.reported_at < ?', 'OK', Date.today - days.to_i.days ]
    }
  }

  # Return fridges that have had at least +count+ status updates in the past +days+ days which are not OK.
  named_scope :persistent_problems, lambda{|count,days|
    join = [ (<<-SQL).squish, 'OK', Date.today - days.to_i.days, count.to_i ]
      INNER JOIN fridge_statuses AS fs
              ON fridges.id = fs.fridge_id
             AND fs.id = (SELECT id
                            FROM fridge_statuses
                           WHERE fridge_id = fs.fridge_id
                             AND fridge_statuses.status_code <> ?
                             AND fridge_statuses.reported_at >= ?
                        GROUP BY id
                          HAVING COUNT(1) >= ?
                           LIMIT 1)
    SQL
    {
      :include => :current_status,
      :joins => sanitize_sql(join)
    }
  }

  # Return fridges that do not have a status update in the past +days+ days.
  named_scope :neglected, lambda{|days|
    {
      :conditions => [ 'fs.reported_at < ?', Date.today - days.to_i.days ],
      :joins => (<<-SQL).squish
        INNER JOIN fridge_statuses AS fs
                ON fridges.id = fs.fridge_id
               AND fs.id = (SELECT id
                             FROM fridge_statuses fs2
                             WHERE fridge_id = fs.fridge_id
                          ORDER BY fs2.reported_at DESC
                             LIMIT 1)
      SQL
    }
  }
  
  # Return fridges that:
  #  * are currently 'OK', and
  #  * have a status update that is not 'OK', and 
  #  * have no status update of 'OK' between the bad status and +days+ ago.
  # These conditions imply that the current 'OK' status must have been in the past +days+ days. 
  named_scope :recently_fixed, lambda{|days|
    {
      :include => :current_status,
      :conditions => [ (<<-SQL).squish, { :ok => 'OK', :recent => Date.today - days.to_i.days } ]
        fridge_statuses.status_code = :ok
        AND EXISTS (SELECT 1 FROM (select fridge_id, max(fs.reported_at) as reported_at
                                      FROM fridge_statuses fs
                                      WHERE fs.status_code <> 'OK'
                                      GROUP BY fridge_id) prob
                    WHERE prob.fridge_id = fridges.id
                    AND NOT EXISTS (select 1 from fridge_statuses fixed 
                                              WHERE fixed.fridge_id = fridges.id 
                                              AND fixed.status_code = :ok
                                                AND fixed.reported_at BETWEEN prob.reported_at AND :recent))
      SQL
    }
  }

  named_scope :status_category, lambda { |category|
    {
      :include => :current_status, 
      :conditions => [ (<<-SQL).squish, { :statuses => FridgeStatus.statuses_in_category(category) } ]
        COALESCE(fridge_statuses.status_code, 'NO STATUS') IN (:statuses)
        AND fridge_statuses.reported_at IS NOT NULL
      SQL
    }
  }

  named_scope :age_category, lambda { |category|
    #[PSQL-Note] In PSQL, param of interval needs to be single-quoted, e.g., interval '1 month'
    cond = (case category
            when '1mo' then " > '#{Date.today.strftime("%Y-%m-%d")}' - interval 1 month"
            when '2mo' then " BETWEEN '#{Date.today.strftime("%Y-%m-%d")}' - interval 1 month AND '#{Date.today.strftime("%Y-%m-%d")}' - interval 2 month"
            when '3mo' then " < '#{Date.today.strftime("%Y-%m-%d")}' - interval 2 month"
            end)

    { :include => :current_status, 
      :conditions => "fridge_statuses.reported_at #{cond}"
    }
  }

  def recent_history(n=5, o=0)
    fridge_statuses.all(:limit => n, :offset => o)
  end
  
  def stock_room
    current_status ? current_status.stock_room : nil
  end
  
  def health_center
    stock_room ? stock_room.health_center : nil
  end

  def field_coordinator
    stock_room ? stock_room.health_center.delivery_zone.field_coordinator : nil
  end

  def ok?
    current_status ? current_status.status_code == 'OK' : nil
  end
  
  def location
    stock_room ? stock_room.place : nil
  end
  
  def latest_status
    fridge_statuses.first
  end
  
  alias_method :last_operating_status, :latest_status
  
  def urgent?
    current_status ? current_status.urgent? : nil
  end

  def status_category
    current_status ? current_status.status_category : 'yellow'
  end
  
  def age_category
    if current_status
      age = (Date.today - current_status.date).to_i
      if age < 1.month / 1.days
        '1mo'
      elsif age < 2.month / 1.days
        '2mo'
      else
        'old'
      end
    else
      'none'
    end
  end
  
  report_column :code,                  :sql_sort => 'fridges.code', :header => "headers.fridge_code", :type => :link, :data_proc => lambda { |f| [f.code, f ] }
  report_column :health_center,         :sql_sort => 'administrative_areas.code', :header => "headers.health_center", :data_proc => lambda { |r| r.location.label }
  report_column :district,              :sortable => false, :header => "headers.district",      :data_proc => lambda { |r| r.location.administrative_area.parent.label if r.location && r.location.administrative_area.parent }
  report_column :latest_status,         :sql_sort => 'fridge_statuses.status_code', :header => "headers.status",        :data_proc => lambda { |r| r.current_status && r.current_status.i18n_status_code }
  report_column :latest_temp,           :sql_sort => 'fridge_statuses.temperature', :header => "headers.temperature",   :type => :int, :data_proc => lambda { |r| r.current_status && r.current_status.temperature }
  report_column :date_of_latest_status, :sql_sort => 'fridge_statuses.reported_at', :header => "headers.status_date",   :type => :date,    :data_proc => lambda { |r| r.current_status && r.current_status.reported_at }
  report_column :reported_by,           :sql_sort => 'users.name', :header => "headers.reported_by",   :data_proc => lambda { |r| r.current_status && r.current_status.user_name }
  report_column :history_popup,         :header => "headers.history_popup", :data_proc => lambda { |r| "" }, :sortable => false
  report_column :more_info_popup,       :header => "headers.more_info_popup", :data_proc => lambda { |r| "" }, :sortable => false
  report_column :update_link,           :header => "headers.update_link", :sortable => false, :type => :link, :data_proc => lambda { |r| [I18n.t("edit"), [:edit, r] ] }
  
end


