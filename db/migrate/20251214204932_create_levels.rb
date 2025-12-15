class CreateLevels < ActiveRecord::Migration[7.1]
  def change
    create_table :levels do |t|
      t.float :level_height
      t.references :section, null: false, foreign_key: true

      t.timestamps
    end
  end
end
