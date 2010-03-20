class UsersController < OlmisController
  unloadable

  add_breadcrumb 'breadcrumb.users', 'users_path', :except => [ :profile ]

  def index
  end
  
  def show
    @user = User.find_by_id(params[:id])
  end
  
  def new
    @user = User.new
    add_breadcrumb 'breadcrumb.new_user', new_user_path
    render :action => :edit
  end

  def edit
    @user = User.find_by_id(params[:id])
    add_breadcrumb 'breadcrumb.edit_user', user_path(@user)
  end
  
  def create
    User.transaction do
      begin
        @user = User.new(params[:user])
        @user.save!
        redirect_to users_url
      rescue ActiveRecord::ActiveRecordError
        render :action => :new
      end
    end
  end
  
  def update
    User.transaction do
      begin
        @user = User.find_by_id(params[:id])
        @user.update_attributes!(params[:user])
        redirect_to users_url
      rescue ActiveRecord::ActiveRecordError
        render :action => :edit
      end
    end
  end
  
  def profile
    @user = User.find_by_id(params[:id])
    add_breadcrumb 'breadcrumb.user_profile', profile_user_path
    if (request.put? || request.post?) && (@user == @current_user || @current_user.admin?) 
      redirect_to profile_user_path(@user) and return if @user.update_attributes(params[:user])
    end
    @minimal_layout = true
  end

end
