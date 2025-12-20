class Level < ApplicationRecord
  belongs_to :section

  has_many :articles # Added to allow greedy space calculation
end
