class CreateStores < ActiveRecord::Migration[7.1]
  def change
    create_table :stores do |t|
      t.string :store_loc
      t.integer :store_num

      t.timestamps
    end
  end
end
