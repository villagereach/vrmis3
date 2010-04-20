class OlmisRedefineFridgeStatus < ActiveRecord::Migration
  def self.up
    add_column    :fridge_statuses, :past_problem, :boolean
    change_column :fridge_statuses, :status_code, :string, :null => true
    rename_column :fridge_statuses, :notes, :other_problem
  end

  def self.down
    rename_column :fridge_statuses, :other_problem, :notes
    change_column :fridge_statuses, :status_code, :string, :null => false
    remove_column :fridge_statuses, :past_problem
  end
end
