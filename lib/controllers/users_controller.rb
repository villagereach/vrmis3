class UsersController < OlmisController
  def show
    @user = User.find_by_id(params[:id])
  end
  
  
  def profile
    @user = User.find_by_id(params[:id])
    if request.put? || request.post?
      redirect_to root_path and return if @user.update_attributes(params[:user])
    end
    @minimal_layout = true
  end

end
