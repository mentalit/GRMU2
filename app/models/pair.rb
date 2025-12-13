class Pair < ApplicationRecord
  belongs_to :store
  has_many :aisles
end
