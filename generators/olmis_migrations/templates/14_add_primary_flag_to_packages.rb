class OlmisAddPrimaryFlagToPackages < ActiveRecord::Migration
  def self.up
    add_column :packages, :primary_package, :boolean, :null => false, :default => true
  end

  def self.down
    remove_column :packages, :primary_package
  end
end
