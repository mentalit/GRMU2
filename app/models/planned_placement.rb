class PlannedPlacement < ApplicationRecord
  belongs_to :article
  belongs_to :aisle
  belongs_to :section
  belongs_to :level

  validates :qty, numericality: { greater_than: 0 }
end