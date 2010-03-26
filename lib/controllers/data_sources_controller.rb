class DataSourcesController < OlmisController
  unloadable

  skip_before_filter :check_logged_in, :only => [ :list_xforms, :submit_xform ]

  protect_from_forgery :except => :submit_xform

  add_breadcrumb 'breadcrumb.data_sources', 'data_sources_path', :except => [ :list_xforms, :submit_xform ]

  helper :visits
  
  def import
    data_source = DataSource.new(params[:file])
    if data_source.save
      flash[:notice] = t("data_sources.upload_successful")
    else
      flash[:error] = t("data_sources.upload_failed", :reason => data_source.error)
    end
    redirect_to data_sources_url
  end

  def list_xforms
    respond_to do |format|
      format.xml
    end
  end

  def submit_xform
    data = DataSubmission.new(
      :user => current_user || User.admin,
      :remote_ip => request.remote_ip)
    
    status, visit = data.handle_request(request)

    respond_to do |format|
      format.html do
        if data.data_source.is_a?(AndroidOdkVisitDataSource)
          headers['Location'] = xform_submit_url
        else
          headers['Location'] = data_sources_url
        end
        
        if visit && status < 300 && !data.data_source.is_a?(AndroidOdkVisitDataSource)
          redirect_to headers['Location']
        else
          render :nothing => true, :status => status
        end
      end
    end
  end
end
