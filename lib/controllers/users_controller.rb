class UsersController < OlmisController
  unloadable

  def show
    @user = User.find_by_id(params[:id])
  end
  
  
  def index
  end
  
  def new
    @user = User.new
  end

  def edit
    @user = User.find_by_id(params[:id])
    render :profile
  end
  
  def update 
    create
  end

  def create
    if (request.put? || request.post?) && @current_user.admin?
      User.transaction do
        begin
          @user = params[:id] ? User.find_by_id(params[:id]) : User.new(params[:user])
          @user.save!
          redirect_to profile_user_path(@user)
        rescue ActiveRecord::ActiveRecordError
          render :new
        end
      end
    end
  end
  
  def profile
    @user = User.find_by_id(params[:id])
    if (request.put? || request.post?) && (@user == @current_user || @current_user.admin?) 
      redirect_to profile_user_path(@user) and return if @user.update_attributes(params[:user])
    end
    @minimal_layout = true
  end

end
