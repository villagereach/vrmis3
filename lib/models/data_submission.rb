# == Schema Information
# Schema version: 20100419182754
#
# Table name: data_submissions
#
#  id             :integer(4)      not null, primary key
#  data_source_id :integer(4)      not null
#  user_id        :integer(4)      not null
#  created_on     :date
#  created_by     :integer(4)
#  content_type   :string(255)
#  character_set  :string(255)
#  remote_ip      :string(255)
#  filename       :string(255)
#  status         :string(255)
#  message        :string(255)
#  data           :text
#  created_at     :datetime
#  updated_at     :datetime
#

class DataSubmission < ActiveRecord::Base
  belongs_to :user
  belongs_to :data_source
  has_and_belongs_to_many :health_center_visits
  
  columns_on_demand :data
  
  validates_presence_of :user
  validates_presence_of :data_source

  def self.last_submit_time
    if last = self.last(:order => 'created_at')
      last.created_at
    else
      Time.parse('2010-01-01 00:00:00')
    end
  end

  def content_type=(type)
    if type =~ /charset=([\w\-]+)/
      self.character_set = $1
    end
    
    super(type)
  end

  def handle_request(request)
    file_param = request.params.keys.detect { |k| request.params[k].respond_to?(:'[]') && request.params[k]['data'].respond_to?(:read) }
    
    if file_param
      # Web-based XForms submission
      self.filename = (request.headers["rack.request.form_hash"][file_param]['data'][:filename] rescue nil)
      self.data = request.params[file_param]['data'].read
      ct = (request.headers["rack.request.form_hash"][file_param]['data'][:type] rescue request.headers['CONTENT_TYPE'])
      self.content_type = ct
    else
      file_param = request.params.keys.detect { |k| request.params[k].respond_to?(:read) }
      if file_param
        # ODK XForms submission
        self.filename = (request.headers["rack.request.form_hash"][file_param][:filename] rescue nil)
        self.data = request.params[file_param].read
        ct = (request.headers["rack.request.form_hash"][file_param][:type] rescue request.headers['CONTENT_TYPE'])
        self.content_type = ct
      else
        self.data = request.raw_post
        self.content_type = request.headers['CONTENT_TYPE']
      end
    end

    if request.params.has_key?(:xml_submission_file)
      self.data_source = DataSource['AndroidOdkVisitDataSource']
      ok_status = 201
    elsif request.content_type.to_s == 'application/xml'
      self.data_source = DataSource['XformVisitDataSource']
      ok_status = 200
    end
          
    save!
    
    # NOTE: Response data is taken from the ODK Aggregate code.

    # On success, ODK Collect expects a HTTP 201 response code, a valid Location
    # header, and ignores anything in the response body, so send an empty body.
    # The response content type doesn't seem to matter, but ODK Aggregate sends
    # an HTML response so we'll do the same.
    #
    # On success, XSLTForms expects a HTTP 200 response code.
    #
    # On failure, ODK Aggregate sends a HTTP 400 response code, but ODK Collect
    # doesn't seem to care -- if the response code != 201 it considers the
    # submission to have failed. Similarly, XSLTForms considers any response code
    # other than 200 to be an error.

    status = ok_status
    errors = []
    visit = nil
    
    HealthCenterVisit.transaction do 
      visit, errors = process_visit(nil, nil, current_user)
      if errors.present?
        status = 400
        raise ActiveRecord::Rollback
      else
        update_attributes(:status => 'success')
      end
    end

    if errors.present?
      update_attributes(:status => 'errors')
    end
    
    return status, visit
  end    
  
  def process_visit(health_center=nil, visit_month=nil, user=nil)
    @params, @visit_errors = data_source.data_to_params(self)

    if @params[:health_center_visit]
      health_center ||= HealthCenter.find_by_code(@params[:health_center_visit][:health_center])
      visit_month ||= @params[:health_center_visit][:visit_month]
      
      if (!visit_month && @params[:health_center_visit][:epi_month])
        visit_month = (Date.parse(@params[:health_center_visit][:epi_month] + '-01') + 1.month).strftime("%Y-%m")
        @params[:health_center_visit][:visited_at] ||= visit_month + '-01'
      end
      
      @params[:health_center_visit][:vehicle_code] ||= ''    
      @params[:health_center_visit].delete(:health_center)
      @params[:health_center_visit].delete(:visit_month)
      @params[:health_center_visit].delete(:epi_month)
    end
    
    raise [self, @params, health_center, visit_month].inspect unless @params && health_center && visit_month

    @current_user = user
    @visit_errors ||= { }
    @visit = HealthCenterVisit.find_or_initialize_by_health_center_id_and_visit_month(health_center.id, visit_month)
    
    process_health_center_visit if @params[:health_center_visit] 

    @visit.field_coordinator ||= @current_user
    @visit.updated_at = Time.now
    @visit.save!
    
    @visit_errors[:health_center_visit] = @visit.errors unless @visit.errors.empty?
    
    self.health_center_visits << @visit unless health_center_visits.include?(@visit)

    process_fridge_statuses if @params[:fridge_status]
    process_equipment if @params[:equipment_status]
    process_stock_cards if @params[:stock_card_status]
    process_inventory if @params[:inventory_counts]
    process_tallies
    
    if @visit.overall_status == HealthCenterVisit::REPORT_COMPLETE
      self.message = "complete"
    else
      self.message = "incomplete"
    end
    
    return @visit, @visit_errors
  end
  
  def description
    I18n.t("DataSubmission.#{message}", :source => data_source.description, :date => I18n.l(created_on || created_at.to_date, :format => :long), :user => (created_by || user).name)
  end

  def process_stock_cards
    stock_card_statuses = @visit.find_or_initialize_stock_card_statuses

    @params[:stock_card_status].each do |key, values|
      record = stock_card_statuses.detect{|s| s.stock_card_code == key}

      # Skip if no data entered for a new item
      next if record.new_record? && values["have"].blank? && values["used_correctly"].blank?

      db_values = values.inject({}){|hash,(key,value)| hash[key] = value == "true" || (value == "false" ? false : nil) ; hash }

      record.date = @visit.date
      record.update_attributes(db_values)
      unless record.errors.empty?
        @visit_errors[:stock_card_status] ||= {}
        @visit_errors[:stock_card_status][key] = record.errors
      end
    end
  end

  def process_equipment
    equipment_statuses = @visit.find_or_initialize_equipment_statuses

    equipment_notes = @params[:equipment_status].delete(:notes)
    @visit.update_attributes(:equipment_notes => equipment_notes) unless equipment_notes.blank?

    @params[:equipment_status].each do |key, values|
      record = equipment_statuses.detect{|es| es.equipment_type_code == key }

      # Skip if no data entered for a new item
      next if record.new_record? && values["present"].blank? && values["working"].blank?

      db_values = values.inject({}){|hash,(key,value)| hash[key] = value == "true" || (value == "false" ? false : nil) ; hash }

      record.date = @visit.date
      record.update_attributes(db_values)
      unless record.errors.empty?
        @visit_errors[:equipment_status] ||= {}
        @visit_errors[:equipment_status][key] = record.errors
      end
    end
  end    
  
  def process_health_center_visit
    #temporary hiding of epi_data_ready; remove it later if it stays hidden
    @visit.epi_data_ready = true

    visited = @params[:health_center_visit].delete(:visited)    

    reason_for_not_visiting = @params[:health_center_visit].delete(:reason_for_not_visiting)
    other_non_visit_reason  = @params[:health_center_visit].delete(:other_non_visit_reason)

    if ['true','else'].include?(visited)
      @visit.visited = visited
      @visit.reason_for_not_visiting = nil
      @visit.other_non_visit_reason = nil
      @visit.field_coordinator = User.find_by_id(@params[:health_center_visit].delete(:user_id))
    elsif visited == 'false'
      @visit.visited = 'false'
      @visit.reason_for_not_visiting = reason_for_not_visiting
      @visit.other_non_visit_reason = other_non_visit_reason #if reason_for_not_visiting == 'other'
      @visit.vehicle_code = nil
    end

    @visit.attributes = (@params[:health_center_visit])
  end
    
  def process_fridge_statuses
    fridge_statuses = @visit.find_or_initialize_fridge_statuses
    
    @params[:fridge_status].each do |key, values|
      # Skip if no data entered for this fridge
      next if values["temperature"].blank? && values["past_problem"].blank? &&
        values["state"].blank? && values["problem"].blank? && values["other_problem"].blank?

      if record = fridge_statuses.detect{|fs| fs.fridge_code == key.to_s }
        db_values = {
          :past_problem => values["past_problem"] == "true" || (values["past_problem"] == "false" ? false : nil),
          :temperature      => values["temperature"].blank? ? nil : values["temperature"].to_i,
          :status_code      => values["state"] == "OK" ? "OK" : values["state"] == "nr" ? nil : values["problem"].join(' '),
          :other_problem    => values["state"] == "problem" && values["problem"].include?("OTHER") ? values["other_problem"] : nil
        }
        record.update_attributes(db_values)
        unless record.errors.empty?
          @visit_errors[:fridge_status] ||= {}
          @visit_errors[:fridge_status][key] = record.errors
        end
      else
        # TODO: The fridge code changed; should this be possible in the online form?
      end
    end
  end

  def process_equipment_nr_params(params)
    attrs = params.reject{|k,v| k.ends_with?('/NR')}
    attrs.each do |k,v|
      v = nil if params.has_key?(k + '/NR') && params[k + '/NR'] == 1
    end
    attrs
  end

  def process_inventory
    inventories = @visit.find_or_create_inventory_records
    stock = @visit.ideal_stock

    @params[:inventory_counts].each do |key, value|
      (stock.keys - [:ideal]).each do |type|
        if (record = stock[type][key]) && value.has_key?(type)
          if value[type].blank? && value["#{type}/NR"].to_i == 0
            # No quantity value is specified and NR is not checked
            record.delete unless record.new_record?
          else
            # A quantity value is specified or NR is checked
            record.quantity = (value.has_key?("#{type}/NR") && value["#{type}/NR"].to_i == 1) ? nil : value[type]
            record.save
            unless record.errors.empty?
              @visit_errors[key] ||= {}
              @visit_errors[key][type] = record.errors
            end
          end
        end
      end
    end

    # Remove any blank package counts
    inventories.each { |i|
      i.package_counts.delete_if{|pc| pc.id.nil?}
      i.save
    }
  end
  
  def process_tallies
    HealthCenterVisit.tally_hash.each do |tally, value|
      if @params[tally]
        records, tally_errors = tally.constantize.create_or_replace_records_by_keys_and_user_from_data_entry_group(
          [@visit.health_center_id, @visit.epi_month], 
          @visit.field_coordinator,
          @params[tally])
        
        @visit_errors[tally] = tally_errors unless tally_errors.empty?
      end
    end
  end

  
end


