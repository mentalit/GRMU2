class AddLevelIdToArticlesAndRemoveLevelNumber < ActiveRecord::Migration[7.0]
  def up
    add_reference :articles, :level, foreign_key: true, index: true, null: true

    # Optional backfill if safe
    execute <<~SQL
      UPDATE articles
      SET level_id = levels.id
      FROM levels
      WHERE levels.section_id = articles.section_id
    SQL

    remove_column :articles, :level_number
  end

  def down
    add_column :articles, :level_number, :integer
    remove_reference :articles, :level, foreign_key: true
  end
end