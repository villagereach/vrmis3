class VisitsController < OlmisController
  helper :progress
  
  before_filter :setup_visit_entry_pages_and_clear_caches, :except => [:index,:search,:by_month,:nuke_caches]

  add_breadcrumb 'breadcrumb.site_visits', 'visits_path'
  add_breadcrumb lambda { |c| helpers.hcv_month(c.visit_month, :format => 'breadcrumb.epi_visit_month') }, 'visits_by_month_path', :except => [:index,:search]
  add_breadcrumb lambda { |c| c.health_center.name }, 'health_center_visit_path', 
  :only => [:health_center_monthly_visit, :health_center_cold_chain, :health_center_equipment, :health_center_stock_cards,
              :health_center_inventory, :health_center_tally]
  add_breadcrumb 'breadcrumb.visit_search', '', :only=> [:search]
  add_breadcrumb 'breadcrumb.inventory', '', :only => [:health_center_inventory]
  add_breadcrumb 'breadcrumb.cold_chain', '', :only => [:health_center_cold_chain]
  add_breadcrumb 'breadcrumb.equipment', '', :only => [:health_center_equipment]
  add_breadcrumb 'breadcrumb.stock_cards', '', :only => [:health_center_stock_cards]
  add_breadcrumb 'breadcrumb.epi', '', :only => [:health_center_tally]

  def search
    @health_centers = HealthCenter.all(:include => :health_center_visits,
                                       :conditions => [ 'health_centers.name LIKE ? AND health_centers.delivery_zone_id = ?', "#{params[:health_center][:name]}%", @current_user.delivery_zone ],
                                       :order => 'health_centers.name')
  end
  
  def by_month
  end
  
  def health_center
    @health_center
  end

  def sub_layout
    @is_visit_entry_page ? 'visit_entry_page' : super    
  end

  private
  
  def handle_submit(ps = {})
    if params[:format] == 'xml'
      submission = DataSubmission.create(
        :user => @current_user, 
        :data_source => DataSource['XformVisitDataSource'],
        :remote_ip => request.remote_ip,
        :content_type => request.headers['CONTENT_TYPE'].to_s,
        :data => request.raw_post)
    else
      submission = DataSubmission.create(
        :user => @current_user, 
        :data_source => DataSource['WebVisitDataSource'],
        :remote_ip => request.remote_ip,
        :content_type => request.headers['CONTENT_TYPE'].to_s,
        :data => request.raw_post)
    end

    HealthCenterVisit.transaction do
      @visit, @errors = submission.process_visit(@health_center, helpers.visit_month, @current_user)
    end    

    if @errors.empty?
      submission.status = 'success'
      submission.save

      if params[:format] == 'xml'
        render :text => 'ok'
      else
        if params[:save_and_continue] && link = helpers.next_link      
          redirect_to link.last
        else
          redirect_to(ps)
        end
      end
    else
      submission.status = 'error'
      submission.save
    end
  end    

  public

  def index
    if request.xhr?
      render :partial => '/visits/recent_activity.html'
    end
  end
  
  def health_center_monthly_visit
    @visit ||= HealthCenterVisit.new(:health_center => @health_center, :visit_month => helpers.visit_month)
    handle_submit if request.post? || request.put?
  end

  def health_center_monthly_visit_title
    @visit ||= HealthCenterVisit.new(:health_center => @health_center, :visit_month => helpers.visit_month)
    render :text => @health_center.name + ', ' + @visit.date_period
  end
  
  def health_center_cold_chain
    @fridge_statuses = @visit.find_or_initialize_fridge_statuses
    handle_submit if request.post?
  end

  def health_center_equipment
    equipment_counts, equipment_statuses = @visit.find_or_initialize_equipment
    @equipment = equipment_counts.zip(equipment_statuses)

    handle_submit if request.post?
  end

  def health_center_stock_cards
    @stock_card_statuses = @visit.find_or_initialize_stock_card_statuses

    handle_submit if request.post?
  end

  def health_center_inventory
    @inventories = @visit.find_or_create_inventory_records
    @stock = @visit.ideal_stock 

    handle_submit if request.post?
  end
  
  def health_center_tally
    handle_submit if request.post?
    respond_to do |format|
      format.html {
        
      }
      if @current_user.admin? 
        format.erb  {
          tally_class = params[:tally].constantize
          render :text =>
            "<!-- Save this as #{Rails.root.join("app/views/visits/_#{params[:tally].underscore}.html.erb")} -->\n" +
            "<!-- Modifications made there will appear in the online form. -->\n" +
            helpers.tally_table(tally_class, 
              lambda { |point| helpers.tally_field(tally_class.name, tally_class.param_name(point), {}, :tally_form_erb) },
              lambda { |val1, val2| "<%= #{tally_class}.header_for(#{[val1, val2].map(&:inspect).join(", ")}) %>" })
        }
      end
    end
  end
  
  def current_visit
    @visit
  end
 
  private
  
  def setup_visit_entry_pages_and_clear_caches
    month = helpers.visit_month
    @health_center = HealthCenter.find_by_code(params[:health_center])
    @visit = HealthCenterVisit.find_by_health_center_id_and_visit_month(@health_center, month)
    @is_visit_entry_page = true  #determines sub-layout
    @errors = {}
    helpers.expire_caches_for_hc_month(@health_center, month)
    redirect_to :health_center_visit if !request.xhr? && !@visit && params[:action] != 'health_center_monthly_visit' 
  end  

  
end
