class DataSourcesController < OlmisController
  skip_before_filter :check_logged_in, :only => [ :list_xforms, :submit_xform, :get_xform, :get_offline ]
  skip_before_filter :set_locale,      :only => [ :manifest, :get_xform, :get_offline ]
  before_filter :set_locale_without_session, :only => [ :manifest, :get_xform, :get_offline ]

  protect_from_forgery :except => :submit_xform

  add_breadcrumb 'breadcrumb.data_sources', 'data_sources_path', :except => [ :list_xforms, :submit_xform, :get_xform, :get_offline ]

  helper :visits
  helper :date_period_range
  
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
    manifest_data = render_to_string(:action => "manifest.#{params[:format]}", :layout => false)

    vendor_root = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
    lib_path    = File.join(vendor_root, 'lib')
    views_path  = File.join(vendor_root, 'lib', 'views')

    files = manifest_data.split("\n").map(&:strip).grep(/^\//).map { |f| File.join(Rails.root, 'public', f) }.select { |f| File.exists?(f) } 
    if params[:format] == "xforms"
      files += [ File.join(views_path, 'data_sources', 'hcvisit.xhtml.erb') ]
      files += Dir.glob(File.join(views_path, 'data_sources', '*.xml'))
    else
      files += [ File.join(views_path, 'data_sources', 'hcvisit.html.erb') ]
    end
    files += Dir.glob(File.join(views_path, 'data_sources', params[:format], '*.erb'))
    files += Dir.glob(File.join(views_path, 'reports', '*.erb'))
    files += Dir.glob(File.join(Rails.root, 'app', 'views', 'data_sources', params[:format], '*.erb'))
    files += Dir.glob(File.join(Rails.root, 'app', 'views', 'reports', params[:format], '*.erb'))
    files += Dir.glob(File.join(lib_path, '{graphs,reports,queries}.rb'))
    files += [ File.join(views_path, 'javascripts', 'offline_i18n.js.erb'),
               File.join(views_path, 'javascripts', 'offline_autoeval_data.js.erb'),
               File.join(views_path, 'data_sources', "manifest.#{params[:format]}.erb"),
               File.join(views_path, 'layouts', 'offline.html.erb') ]
    files << __FILE__

    last_mod_time = (files.map{ |f| File.mtime(f).to_i } << DataSubmission.last_submit_time.to_i).max

    send_data(manifest_data.gsub('# version', "# version: #{last_mod_time}"), :type => 'text/cache-manifest')
  end
  
  def get_offline
    @rendering_for_offline_form = true

    vendor_root = File.expand_path(File.join(File.dirname(__FILE__), '..','..'))
    files  = Dir.glob(File.join(Rails.root,  'app', 'views', 'data_sources', 'offline', '*.erb'))
    files += Dir.glob(File.join(vendor_root, 'lib', 'views', 'data_sources', 'offline', '*.erb'))
    files << File.join(vendor_root, 'lib', 'views', 'data_sources', "#{params[:name]}.html.erb")

    last_mod_time = files.map{ |f| File.mtime(f) }.max

    # NOTE: The stale? check doesn't work because a 304 status may result in
    #       Firefox 3.6 refusing to reload the page because, even though
    #       other offline manifest components changed, this page did not.
    #       (Safari 4.x has no such problem; Chrome was not tested.)
    #       The workaround is to use the controller cache instead.
    #
    # if stale?(:last_modified => last_mod_time.utc)
    #   render :action => params[:name], :layout => false
    # end

    text = cache("#{params[:action]}-#{params[:name]}-#{I18n.locale}-#{last_mod_time.to_i}") do
      render_to_string(:action => params[:name], :layout => false)
    end
    render(:text => text, :layout => false)
  end

  def get_xform
    respond_to do |format|
      format.xml {
        text = render_to_string(:action => params[:name], :layout => false)
        send_data(text.gsub(/<!--.*?--\s*>/m,'').squish, :type => 'text/xml', :disposition => 'inline')
      }
      format.xhtml {
        text = render_to_string(:action => params[:name], :layout => false)
        send_data(text, :type => 'text/xml', :disposition => 'inline')
      }
      format.html {
        vendor_root = File.expand_path(File.join(File.dirname(__FILE__), '..','..'))

        file     = File.join(vendor_root, 'lib', 'views', 'data_sources', "#{params[:name]}.xhtml.erb")
        jsfile   = File.join(Rails.root, 'public', 'xforms', 'xsltforms', 'xsltforms.js')
        cssfile  = File.join(Rails.root, 'public', 'xforms', 'xsltforms', 'xsltforms.css')
        xsltfile = File.join(vendor_root, 'public', 'xforms', 'xsltforms', 'xsltforms.xsl')

        files  = Dir.glob(File.join(Rails.root,  'app', 'views', 'data_sources', 'xforms', '*.xforms.erb'))
        files += Dir.glob(File.join(vendor_root, 'lib', 'views', 'data_sources', 'xforms', '*.xforms.erb'))
        files += [ file, jsfile, cssfile, xsltfile, __FILE__ ]

        last_mod_time = files.map{ |f| File.mtime(f) }.max

        if_modified_since(last_mod_time) do
          text = cache("#{params[:action]}-#{params[:name]}-#{I18n.locale}-#{last_mod_time.to_i}") do
            s = render_to_string(:file => "data_sources/#{params[:name]}.xhtml", :layout => false).gsub(/<!\s*(?:--(?:[^\-]|[\r\n]|-[^\-])*--\s*)>/,'')
            xml = Nokogiri::XML(s)

            # Parse the XSLT and perform some required fixups
            xsl = Nokogiri::XML(File.read(xsltfile))
            output_node = xsl.xpath('//xsl:output').first

            # XSLTforms is encoded as ISO-8859-1 but our XML is UTF-8 -- the characters are translated
            # correctly by Nokogiri but the encoding declaration is not.
            output_node['encoding'] = 'UTF-8'

            # The default XML output format doesn't work so it's changed to HTML (which has been the
            # default in some versions of XSLTForms).
            output_node['method'] = 'html'

            # Because nokogiri/libxml2/libxslt can't generate a HTML5 DOCTYPE,we need to prevent a
            # DOCTYPE from being generated by discarding the doctype values inthe xsl:output element
            # and then inserting a HTML5 DOCTYPE in the output (below).
            output_node.attribute_nodes.each do |attr|
              output_node.delete(attr.name) if attr.name.starts_with?('doctype')
            end

            xslt = Nokogiri::XSLT(xsl.to_s)
  
            params = Nokogiri::XSLT.quote_params(['baseuri', '/xforms/xsltforms/'])

            "<!DOCTYPE html>\n" +
              Dir.chdir(File.dirname(xsltfile)) {
                xslt.transform(xml, params).to_s.gsub(/<\?(?:xml|xsltforms-options|css-conversion) [^>]*>/,'').squeeze(' ')
              }
          end
          render(:text => text, :layout => false)
        end
      }
    end
  end
end
