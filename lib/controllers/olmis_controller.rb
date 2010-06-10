# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class OlmisController < ActionController::Base
  protect_from_forgery # See ActionController::RequestForgeryProtection for details
  
  def nuke_caches
    helpers.nuke_all_caches
    flash[:notice] = "cache cleared"  #doesn't seem to be going through
    redirect_to (request.referer || "/")
  end

  def sub_layout
    'application'
  end
  
  protected

  def if_modified_since(time, &block) 
    since = request.if_modified_since
    if since && time <= since
      render :nothing => true, :status => 304
      return true
    else
      response.headers['Last-Modified'] = time.httpdate
      yield
    end
  end
  
  # mostly from http://szeryf.wordpress.com/2008/06/13/easy-and-flexible-breadcrumbs-for-rails/
  # see also the eval() in app/views/layouts/application.html.erb

  def add_breadcrumb name, url = ''
    return if @ignore_breadcrumbs
    @breadcrumbs ||= []
    url = eval(url) if url =~ /_path|_url|@/
    @breadcrumbs << [name, url]
  end

  def self.add_breadcrumb name, url, options = {}
    before_filter options do |controller|
      controller.send(:add_breadcrumb, name, url)
    end
  end

  public
  
  add_breadcrumb 'breadcrumb.home', 'root_path'
  
  # Scrub sensitive parameters from your log
  filter_parameter_logging :password

  before_filter :check_logged_in, :except => ['manifest', 'nuke_caches', 'ping']
  before_filter :set_current_date_period
  before_filter :set_locale, :set_timezone
  before_filter :set_report_scope
  layout 'application'
  
  def set_session_vars
    params.stringify_keys.except('user_id').each do |k, v|
      session[k] = v.blank? ? nil : v
    end
    render :text => 'OK'
  end
    
  
  def render_mini_table
    if request.xhr? && params[:identifier]
      render :partial => "/mini_reports/#{params[:identifier]}",
             :locals => { :limit  => params[:limit].to_i, :offset => params[:offset].to_i }
    end
  end
  
  def helpers
    self.class.helpers.controller = self
    self.class.helpers
  end

  def current_user
    @current_user ||= ActiveRecord::Base.current_user = User.find_by_id(session[:user_id]) if session && session[:user_id]
  end

  def ping
    response.content_type = 'text/plain'
    render :text => 'PONG'
  end

  def logged_in
    response.content_type = 'text/plain'
    render :text => 'Yes'
  end
  
  def check_logged_in
    if !current_user
#       flash[:error] = t("login.please_log_in") # RH:  commenting only, but i really i don't think this is necessary.
      session[:return_to] = request.request_uri unless request.request_uri.split('?').first == is_logged_in_path
      if request.xhr?
        render :text => '', :status => 400
      else
        redirect_to login_path
      end
      return nil
    end
    @suppress_breadcrumbs = (current_user.role.id == 1)
    session[:return_to] = nil
    return current_user
  end
  
  def set_current_date_period
    #this should be set in the common delivery frequency.  For demo/MZ,  per month
    #we should centralize functions around this formatting and math.  Date.to_vr_period or such.
    if dp = params.delete('set_current_date_period')
      session[:current_date_period] = dp
      if params.keys.include? 'visit_month'
        redirect_to params.merge({:visit_month => session[:current_date_period]})
      else
        redirect_to({})
      end
      return false;
    end
    session[:current_date_period] ||= Date.today.to_date_period
    @current_date_period = session[:current_date_period]
    @working_date = (session[:date] || Date.today).strftime("%Y-%m-%d")
    @current_date = Date.today.strftime("%Y-%m-%d")
  end
   
  def delivery_zone_selector
    render :partial => '/shared/delivery_zone_selector'
  end
  
  def district_selector
    render :partial => '/shared/district_selector'
  end
  
  private

  def set_locale
    if params[:locale].present? && I18n.available_locales.include?(params[:locale].to_sym)
      session[:locale] = params.delete(:locale)
    elsif !session[:locale] && @current_user && @current_user.language.present?
      session[:locale] = @current_user.language
    end
    I18n.locale = session[:locale] if session[:locale].present?
  end

  def set_locale_without_session
    I18n.locale = params[:locale] if params[:locale].present?
  end

  def set_timezone
    Time.zone = @current_user.timezone if @current_user && @current_user.timezone
  end

  def set_report_scope
    unless params[:report_scope]
      %w(district delivery_zone province).each do |scope|
        if (i = params["scope_report_to_#{scope}"].to_i) > 0
          params[:report_scope] = "in_#{scope},#{i}" and break
        end
      end
    end
  end

end
