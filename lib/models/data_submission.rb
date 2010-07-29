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
  has_and_belongs_to_many :warehouse_visits
  
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
      if errors.any? { |k,v| v.present? }
        status = 400
        raise ActiveRecord::Rollback
      else
        update_attributes(:status => 'success')
      end
    end

    if errors.any? { |k,v| v.present? }
      update_attributes(:status => 'errors')
    end
    
    return status, visit
  end    

  def process_pickup(visit, user)
    params, @pickup_errors = data_source.data_to_params(self)
    @pickup_errors ||= {}
    
    #force connection to FC for the DZone
    user = visit.health_center.delivery_zone.field_coordinator
    process_inventory_pickup(visit, params, user) if params['inventory']

    visit.updated_at = Time.now
    visit.visit_month = visit.date.to_date_period 
    visit.save!

    @pickup_errors['warehouse_visit'] = visit.errors unless visit.errors.empty?

    self.warehouse_visits << visit unless warehouse_visits.include?(visit)
    self.message = 'pickup'

    return visit, @pickup_errors
  end

  def process_inventory_pickup(visit, params, user)
    inventory_counts = Hash[*Package.active.map{|p|
                              [ p, [ visit.request.inventory_type, visit.pickup.inventory_type].inject({}) do |hash, key|
                                  hash[key] = params[:inventory][key][p.code]
                                  hash
                                end ] }.flatten]
    Inventory.transaction do
      [ visit.request, visit.pickup ].each do |inventory|
        inventory.update_attributes!(:user       => user,
                                     :date       => params[:inventory][:date],
                                     :stock_room => visit.warehouse.stock_room)

        inventory_counts.each do |package, amounts|
          pc = PackageCount.find_by_inventory_id_and_package_id(inventory, package)
          pc ||= PackageCount.new(:inventory => inventory, :package => package)
          pc.quantity = amounts[inventory.inventory_type].to_i
          unless pc.save
            @pickup_errors[inventory.inventory_type] ||= {}
            @pickup_errors[inventory.inventory_type][package.code] = pc.errors
          end
        end
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    @pickup_errors['common'] = e.to_s
  end

  def process_visit(health_center=nil, visit_month=nil, user=nil)
    @params, @visit_errors = data_source.data_to_params(self)

    if @params['health_center_visit']
      health_center ||= HealthCenter.find_by_code(@params['health_center_visit'][:health_center])
      visit_month ||= @params['health_center_visit']['visit_month']
      
      if (!visit_month && @params['health_center_visit']['epi_month'])
        visit_month = (Date.parse(@params['health_center_visit']['epi_month'] + '-01') + 1.month).strftime("%Y-%m")
        @params['health_center_visit']['visited_at'] ||= visit_month + '-01'
      elsif (@params['health_center_visit']['visited_at'].empty? && visit_month)
        @params['health_center_visit']['visited_at'] = visit_month + '-01'
      end
      
      @params['health_center_visit']['vehicle_code'] ||= ''    
      @params['health_center_visit'].delete('health_center')
      @params['health_center_visit'].delete('visit_month')
      @params['health_center_visit'].delete('epi_month')
    end
    
    @visit_errors ||= { }
    @visit = HealthCenterVisit.find_or_initialize_by_health_center_id_and_visit_month(health_center.id, visit_month)
    
    process_health_center_visit if @params['health_center_visit'] 

    #force connection to FC for the DZone
    @visit.field_coordinator = @visit.health_center.delivery_zone.field_coordinator
    @visit.updated_at = Time.now
    @visit.save!
    
    @visit_errors['health_center_visit'] = @visit.errors unless @visit.errors.empty?
    
    self.health_center_visits << @visit unless health_center_visits.include?(@visit)

    HealthCenterVisit.tables.each do |table|
      slice = table.table_name.singularize
      @visit_errors[slice] = table.process_data_submission(@visit, @params) if @params[slice]
    end
    
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


  def process_health_center_visit
    #temporary hiding of epi_data_ready; remove it later if it stays hidden
    @visit.epi_data_ready = true

    # Discard localized visit date
    @params['health_center_visit'].delete('i18n_visited_at')

    visited = @params['health_center_visit'].delete('visited')

    reason_for_not_visiting = @params['health_center_visit'].delete('reason_for_not_visiting')
    other_non_visit_reason  = @params['health_center_visit'].delete('other_non_visit_reason')

    if ['true','else'].include?(visited)
      @visit.visited = visited
      @visit.reason_for_not_visiting = nil
      @visit.other_non_visit_reason = nil
      @visit.field_coordinator = User.find_by_id(@params['health_center_visit'].delete('user_id'))
    elsif visited == 'false'
      @visit.visited = 'false'
      @visit.reason_for_not_visiting = reason_for_not_visiting
      @visit.other_non_visit_reason = other_non_visit_reason #if reason_for_not_visiting == 'other'
      @visit.vehicle_code = nil
    end

    @visit.attributes = (@params['health_center_visit'])
  end
end


