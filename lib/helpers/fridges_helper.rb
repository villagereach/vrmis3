module FridgesHelper

  def current_status_code_column(f)
    f.current_status.i18n_status_code
  end

  def current_status_date_column(f)
    I18n.l(f.current_status.date)
  end
  
  def status_temperature_c_maybe(fs)
    "#{fs.temperature}C" unless fs.temperature.nil?
  end
  
  def current_status_temperature_c_maybe(f)
    '<li>' + status_temperature_c_maybe(f.current_status) + '</li>' if f.current_status.temperature.present?
  end
  
  def scoped_fridges(scope_string)
    #need to sanitize?
    !scope_string.blank? ? Fridge.send(*scope_string.split(',')) : Fridge
  end
  
  def param_scoped_fridges
    scoped_fridges(params[:report_scope])
  end
    
  def fridge_status_short_form_for(f)
    fs = FridgeStatus.new(:fridge=>f, :reported_at=>Time.now, :user_id => @current_user.id)
    render :partial=>'fridge_statuses/short_form', :locals=>{:fridge_status => fs}
  end
  
  def this_fridge_was_updated(fridge)
    #debug testing:
    return true if params[:fake_update_fridge_id] == fridge.id
    flash[:new_fridge_status] && flash[:new_fridge_status][:fridge_id] == fridge.id
  end
  
  def this_fridge_update_failed(fridge)
    #debug testing:
    return true if params[:fake_update_fridge_id] == fridge.id  && params[:fake_update_failed]
    flash[:new_fridge_status] && flash[:new_fridge_status][:fridge_id] == fridge.id && flash[:new_fridge_status][:id].nil?
  end
  
end

