class Section < ApplicationRecord
  belongs_to :aisle

  # Structural hierarchy
  has_many :levels, dependent: :destroy

  # Articles that currently live in this section (structural)
  has_many :articles

  # ✅ Planning layer (THIS was missing)
  has_many :placements, dependent: :destroy

  # Planned articles in this section (derived from placements)
  has_many :planned_articles,
           -> { distinct },
           through: :placements,
           source: :article
end



