class AddPairCompartmentToPairs < ActiveRecord::Migration[7.1]
  def change
    add_column :pairs, :pair_compartment, :string
  end
end
