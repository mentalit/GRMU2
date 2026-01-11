# db/migrate/XXXXXXXXXX_add_width_used_to_placements.rb
class AddWidthUsedToPlacements < ActiveRecord::Migration[7.1]
  def up
    add_column :placements, :width_used, :decimal, precision: 10, scale: 2

    execute <<~SQL
      UPDATE placements
      SET width_used = 0
      WHERE width_used IS NULL
    SQL

    change_column_null :placements, :width_used, false
  end

  def down
    remove_column :placements, :width_used
  end
end
