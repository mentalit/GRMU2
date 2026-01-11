class CreatePlacements < ActiveRecord::Migration[7.1]
  def change
    create_table :placements do |t|
      t.references :article, null: false, foreign_key: true
      t.references :section, foreign_key: true
      t.references :level, foreign_key: true

      t.decimal :planned_qty, precision: 10, scale: 2, null: false
      t.string :badge

      t.timestamps
    end
  end
end
