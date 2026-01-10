class AddPlanningFieldsToArticles < ActiveRecord::Migration[7.0] # or your Rails version
  def change
    add_column :articles, :part_planned, :boolean, default: false, null: false
    add_column :articles, :planned_quantity_remainder, :integer
  end
end

