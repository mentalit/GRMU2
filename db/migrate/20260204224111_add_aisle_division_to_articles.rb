class AddAisleDivisionToArticles < ActiveRecord::Migration[7.1]
  def change
    add_column :articles, :aisle_division, :string
  end
end
