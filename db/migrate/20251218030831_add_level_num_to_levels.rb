class AddLevelNumToLevels < ActiveRecord::Migration[7.1]
  def change
    add_column :levels, :level_num, :string
  end
end
