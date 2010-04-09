class DashboardController < OlmisController
  helper :progress
  helper :fridges
  helper :visits
  helper :date_period_range
  
  def homepage    
    @params = params.merge({ :report_scope => params[:report_scope] })

    if @current_user.delivery_zone
      @params[:report_scope] ||= "in_delivery_zone,#{@current_user.delivery_zone.id}"
    end

    dashboard = @current_user.role_code + '_dashboard'
    self.send(dashboard) if self.respond_to?(dashboard)
    render :action => dashboard
  end

  protected

  def field_coordinator_dashboard
    @dashboard = "field_coordinator_#{@current_user.advanced? ? 'advanced' : 'basic'}_dashboard"
  end

  def observer_dashboard
    @date_period_range ||= params[:date_period_range] || Date.today.year.to_s
    params[:date_period_range] ||= @date_period_range
    
    label, date_period_range = helpers.parse_date_period_range(params)

    @target_percentage = (params[:target_percentage_id] ?
                          TargetPercentage.find_by_id(params[:target_percentage_id]) : 
                          TargetPercentage.first(:order => 'name asc'))
    
    @map = Maps.districts_by_target_percentage_for_date_period_range(@target_percentage, date_period_range)
  end
  
end
