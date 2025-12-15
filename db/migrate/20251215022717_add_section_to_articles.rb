class AddSectionToArticles < ActiveRecord::Migration[7.1]
  def change
    add_reference :articles, :section, foreign_key: true, null: true
  end
end
