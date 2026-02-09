class AddFieldsToAisles < ActiveRecord::Migration[7.1]
  def change
    add_column :aisles, :type, :string
    add_column :aisles, :loc, :string
    add_column :aisles, :compartment, :string
  end
end
