class AddPlanBadgeToArticles < ActiveRecord::Migration[7.1]
  def change
    add_column :articles, :plan_badge, :string
  end
end
