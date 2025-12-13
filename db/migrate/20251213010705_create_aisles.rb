class CreateAisles < ActiveRecord::Migration[7.1]
  def change
    create_table :aisles do |t|
      t.string :aisle_num
      t.float :aisle_height
      t.float :aisle_depth
      t.float :aisle_section_width
      t.integer :aisle_sections
      t.references :pair, null: false, foreign_key: true

      t.timestamps
    end
  end
end
