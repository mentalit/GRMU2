class AddCompartmentToArticles < ActiveRecord::Migration[7.1]
  def change
    add_column :articles, :compartment, :string
  end
end
