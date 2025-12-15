class AddLevelNumberToArticles < ActiveRecord::Migration[7.1]
  def change
    add_column :articles, :level_number, :integer
  end
end
