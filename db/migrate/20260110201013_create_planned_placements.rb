class CreatePlannedPlacements < ActiveRecord::Migration[7.1]
  def change
    create_table :planned_placements do |t|
      t.references :article, null: false, foreign_key: true
      t.references :aisle,   null: false, foreign_key: true
      t.references :section, null: false, foreign_key: true
      t.references :level,   null: false, foreign_key: true

      t.decimal :qty, precision: 10, scale: 2, null: false

      t.timestamps
    end
  end
end
