class AddBaysToAisles < ActiveRecord::Migration[7.1]
  def change
    add_column :aisles, :bay, :string
  end
end
