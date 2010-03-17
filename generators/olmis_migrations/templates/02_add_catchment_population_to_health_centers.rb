class OlmisAddCatchmentPopulationToHealthCenters < ActiveRecord::Migration
  def self.up
    add_column :health_centers, :catchment_population, :integer
  end

  def self.down
    remove_column :health_centers, :catchment_population
  end
end
