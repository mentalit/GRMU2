class AddEffectiveDtToArticles < ActiveRecord::Migration[6.1]
  def up
    add_column :articles, :effective_dt, :integer

    execute <<~SQL
      UPDATE articles
      SET effective_dt = dt
      WHERE effective_dt IS NULL
    SQL
  end

  def down
    remove_column :articles, :effective_dt
  end
end

