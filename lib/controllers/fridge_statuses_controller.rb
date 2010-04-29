class FridgeStatusesController < OlmisController
  helper :fridges

  def create
    unless params[:fridge_status].length == 1
      flash[:notice] = I18n.t("fridge_statuses.create.error")
    else
      begin
        fs = FridgeStatus.new(params[:fridge_status].values.first.merge(:fridge_id => params[:fridge_status].keys.first))
        flash[:new_fridge_status] = fs
        fs.save!
        flash[:notice] = I18n.t("fridge_statuses.create.ok", :status => fs.i18n_status_code, :fridge => fs.fridge.code, :hc => fs.stock_room.name)
      rescue ActiveRecord::ActiveRecordError
        #handle bad temp for now;  client-side js will solve this
        fs.temperature = nil
        begin
          fs.save!
          flash[:notice] = I18n.t("fridge_statuses.create.no_temp", :status => fs.i18n_status_code, :fridge => fs.fridge.code, :hc => fs.fridge.health_center.name, :temp => params[:fridge_status].values.first[:temperature])
        rescue
          flash[:error] = I18n.t("fridge_statuses.create.problem", :reason => fs.errors.full_messages.join(", "))
        end
      end
    end
    
    redirect_to params[:return_to] || request.referer
  end

end
