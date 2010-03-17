class LoginController < OlmisController
  unloadable
  
  skip_before_filter :check_logged_in

  def logout
    reset_session
    redirect_to root_path
  end

  def login
    #raise I18n.locale# ||= Rails.configuration.i18n.default_locale
    
    if((request.referer !~ /\/log(in|out)\b/) && session[:return_to].nil?)
      session[:return_to] = request.referer
    end
    
    if session[:return_to] == '/'
      session[:return_to] = nil
    end

    if request.post?
      session[:user_id] = nil
      if u = User.authenticate(params[:login][:username].downcase, params[:login][:password])
        u.update_attributes(:last_login => Time.now())

        # HACK: Need to set the user's locale before storing the localized flash message
        params[:locale] = u.language
        set_locale

        session[:user_id] = u.id
        if request.xhr?
          render :text => 'YES'
        else
          redirect_to(session[:return_to] || u.role.landing_page || root_path)
        end
      else
        flash[:notice] = t("login.invalid_login")
        if request.xhr?
          render :text => 'NO', :status => 400
        else
          redirect_to login_path
        end
      end
    end
  end

end
