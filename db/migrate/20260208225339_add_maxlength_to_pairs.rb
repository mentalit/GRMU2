class AddMaxlengthToPairs < ActiveRecord::Migration[7.1]
  def change
    add_column :pairs, :maxlength, :integer
  end
end
