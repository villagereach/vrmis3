class FieldCoordinatorsController < OlmisController
  helper :progress

  add_breadcrumb 'breadcrumb.field_coordinators', 'fc_visits_path'

  def index
    @fcs = User.field_coordinators
  end

  def show
    @fc = User.field_coordinators.find(params[:id])
    add_breadcrumb helpers.hcv_month(params[:visit_month], :format => 'breadcrumb.epi_visit_month'), fc_visits_by_month_path
    add_breadcrumb @fc.name
  end
end
