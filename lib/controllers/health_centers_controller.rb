class HealthCentersController < OlmisController
  unloadable

  add_breadcrumb 'breadcrumb.health_centers', 'health_centers_path'

  def index
  end
  
  def show
    @health_center = HealthCenter.find(params[:id])

    @visit = @health_center.most_recent_visit
    
    @params = {
      :report_scope => "health_center,#{@health_center.id}",
      :suppress_location => true }

    params.merge!(@params)
    add_breadcrumb t('breadcrumb.show_health_center', :name => @health_center.name), health_center_path(@health_center)
  end
  
  def new
    @health_center = HealthCenter.new
    add_breadcrumb 'breadcrumb.new_health_center', new_health_center_path
    render :action => 'edit'
  end
  
  def edit
    @health_center = HealthCenter.find(params[:id])
    add_breadcrumb t('breadcrumb.edit_health_center', :name => @health_center.name), health_center_path(@health_center)
  end

  def update
    @health_center = HealthCenter.find(params[:id])
    begin
      HealthCenter.transaction do 
        @health_center.attributes = params[:health_center]

        if params[:street_address]
          address = @health_center.street_address || StreetAddress.new(:addressed => @health_center)
          @health_center.street_address = address
          address.attributes = (params[:street_address])
        end
        
        if params[:user]
          if params[:user][:name] != @health_center.primary_contact.name 
            @health_center.build_primary_contact()
          end
          @health_center.primary_contact.attributes = (params[:user])
        end
        
        if params[:health_center_catchment]
          @health_center.administrative_area.attributes = (params[:health_center_catchment])
        end

        @health_center.street_address.save!
        @health_center.primary_contact.save!
        @health_center.administrative_area.save!
        @health_center.save!
        redirect_to @health_center
      end
    rescue ActiveRecord::ActiveRecordError
      render :action => 'edit'
    end
  end
  
  def create
    begin
      @health_center = HealthCenter.new(params[:health_center])
      @health_center.save!
      redirect_to @health_center
    rescue ActiveRecord::ActiveRecordError
      render :action => 'edit'
    end
  end
end
