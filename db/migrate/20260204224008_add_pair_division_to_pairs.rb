class AddPairDivisionToPairs < ActiveRecord::Migration[7.1]
  def change
    add_column :pairs, :pair_division, :string
  end
end
