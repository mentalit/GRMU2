class CreatePairs < ActiveRecord::Migration[7.1]
  def change
    create_table :pairs do |t|
      t.string :pair_nums
      t.float :pair_depth
      t.float :pair_height
      t.float :pair_section_width
      t.integer :pair_sections
      t.references :store, null: false, foreign_key: true

      t.timestamps
    end
  end
end
