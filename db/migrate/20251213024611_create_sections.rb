class CreateSections < ActiveRecord::Migration[7.1]
  def change
    create_table :sections do |t|
      t.integer :section_num
      t.float :section_depth
      t.float :section_height
      t.float :section_width
      t.references :aisle, null: false, foreign_key: true

      t.timestamps
    end
  end
end
