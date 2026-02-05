class AddDivisionToPairs < ActiveRecord::Migration[7.1]
  def change
    add_column :pairs, :division, :string
  end
end
