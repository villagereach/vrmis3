class FridgesController < OlmisController
  add_breadcrumb 'breadcrumb.cold_chain', 'cold_chain_path'
  add_breadcrumb 'breadcrumb.fridges',    'fridges_path'

  before_filter :detect_owner
  
  def index
  end
  
  def show
    @fridge = Fridge.find(params[:id])
    @params = {
      :report_scope => "fridge,#{@fridge.id}",
      :exclude_columns => [ :fridge_code, :fridge_health_center, :fridge_district ]
    }
    add_breadcrumb @fridge.code
  end
  
  def new
    @fridge = Fridge.new
    @fridge.stock_room_id = @fridge_owner.stock_room_id if @fridge_owner
    add_breadcrumb 'breadcrumb.new_fridge', new_fridge_path()
    render :action => 'edit'
  end
  
  def edit
    @fridge = Fridge.find(params[:id])
    add_breadcrumb 'breadcrumb.edit_fridge', fridge_path(@fridge)
  end

  def update
    begin
      @fridge = Fridge.find(params[:id])
      @fridge.attributes = params[:fridge]
      @fridge.save!
      redirect_to @fridge
    rescue ActiveRecord::ActiveRecordError
      render :action => 'edit'
    end
  end
  
  def create
    begin
      @fridge = Fridge.new(params[:fridge])
      @fridge.save!
      # Associate the fridge with a stock room by a dummy FridgeStatus
      fs = FridgeStatus.new
      fs.fridge_id = @fridge.id
      fs.user_id = session[:user_id] 
      fs.status_code = 'OTHER'
      fs.stock_room_id = @fridge_owner ? @fridge_owner.stock_room_id : params[:stock_room_id_for_new]
      fs.created_at = fs.updated_at = fs.reported_at = DateTime.now
      fs.save!
      redirect_to @fridge
    rescue ActiveRecord::ActiveRecordError
      render :action => 'edit'
    end
  end
  
  private
  
  def detect_owner
    if params[:health_center_id]
      @fridge_owner = HealthCenter.find_by_id(params[:health_center_id])
      add_breadcrumb(I18n.t('breadcrumb.show_health_center', :name => @fridge_owner.name), 
        health_center_path(@fridge_owner))
    end
  end
end
