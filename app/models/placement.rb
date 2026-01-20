class Placement < ApplicationRecord
   belongs_to :article   # ✅ REQUIRED
  belongs_to :section
  has_one :aisle, through: :section
  belongs_to :level, optional: true

  # after_commit :update_aisle_planned_count, on: [:create, :destroy]

  private

  # def update_aisle_planned_count
  #   aisle&.recalculate_planned_count!
  # end
end

# class Placement < ApplicationRecord 
#   belongs_to :article   # ✅ REQUIRED
#   belongs_to :section
#   belongs_to :level, optional: true

#   has_one :aisle, through: :section
# end





