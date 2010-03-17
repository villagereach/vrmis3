class DataSourcesController < OlmisController
  add_breadcrumb 'breadcrumb.data_sources', 'data_sources_path', :except => [ :list_xforms, :get_xform, :submit_xform ]

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
end
