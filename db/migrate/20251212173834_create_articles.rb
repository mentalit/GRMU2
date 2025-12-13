class CreateArticles < ActiveRecord::Migration[7.1]
  def change
    create_table :articles do |t|
      t.integer :artno
      t.string :artname_unicode
      t.integer :baseonhand
      t.integer :weight_g
      t.string :slid_h
      t.string :ssd
      t.string :eds
      t.string :hfb
      t.float :expsale
      t.string :pa
      t.string :salesmethod
      t.integer :rssq
      t.string :sal_sol_indic
      t.integer :mpq
      t.integer :palq
      t.integer :dt
      t.float :cp_height
      t.float :cp_length
      t.float :cp_width
      t.float :cp_diameter
      t.float :cp_weight_gross
      t.float :ul_height_gross
      t.float :ul_length_gross
      t.float :ul_width_gross
      t.float :ul_diamter
      t.string :new_assq
      t.string :new_loc
      t.integer :split_rssq
      t.references :store, null: false, foreign_key: true

      t.timestamps
    end
  end
end
