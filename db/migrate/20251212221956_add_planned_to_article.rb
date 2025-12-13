class AddPlannedToArticle < ActiveRecord::Migration[7.1]
  def change
    add_column :articles, :planned, :boolean
  end
end
