class DataSourcesController < OlmisController
  skip_before_filter :check_logged_in, :only => [ :list_xforms, :submit_xform, :get_xform ]
  skip_before_filter :set_locale,      :only => [ :manifest, :get_xform ]
  before_filter :set_locale_without_session, :only => [ :manifest, :get_xform ]

  protect_from_forgery :except => :submit_xform

  add_breadcrumb 'breadcrumb.data_sources', 'data_sources_path', :except => [ :list_xforms, :submit_xform, :get_xform ]

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

  def manifest
    manifest_data = render_to_string(:action => 'manifest.txt', :layout => false)

    vendor_root = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
    views_path  = File.join(vendor_root, 'lib', 'views')

    files = manifest_data.split("\n").map(&:strip).grep(/^\//).map { |f| File.join(Rails.root, 'public', f) }.select { |f| File.exists?(f) } 
    files += Dir.glob(File.join(views_path, 'data_sources', '*.xml'))
    files += Dir.glob(File.join(views_path, 'data_sources', '*.erb'))
    files += Dir.glob(File.join(views_path, 'data_sources', 'xforms', '*.xforms.erb'))
    files += Dir.glob(File.join(Rails.root, 'app', 'views', 'data_sources', 'xforms', '*.xforms.erb'))
    files += [ File.join(views_path, 'javascripts', 'offline_i18n.js.erb'),
               File.join(views_path, 'javascripts', 'offline_autoeval_data.js.erb'),
               File.join(views_path, 'layouts', '_locale.html.erb') ]
    files << __FILE__

    last_mod_time = (files.map{ |f| File.mtime(f).to_i } << DataSubmission.last_submit_time.to_i).max

    send_data(manifest_data.gsub('# version', "# version: #{last_mod_time}"), :type => 'text/cache-manifest')
  end
  
  def get_xform
    render :action => params[:name], :layout => false
  end
end
