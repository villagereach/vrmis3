module TargetPercentagesHelper
  def descriptive_values_column(record)
    record.descriptive_values.map(&:label).join(", ")
  end
end
