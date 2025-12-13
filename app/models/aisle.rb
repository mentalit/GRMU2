class Aisle < ApplicationRecord
  belongs_to :pair
  has_many :sections
end
