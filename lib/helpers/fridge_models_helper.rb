module FridgeModelsHelper

  def power_source_form_column(record, input_name)
    select :record, :power_source, FridgeModel.power_sources
  end

end
