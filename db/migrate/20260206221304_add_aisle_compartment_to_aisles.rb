class AddAisleCompartmentToAisles < ActiveRecord::Migration[7.1]
  def change
    add_column :aisles, :aisle_compartment, :string
  end
end
    