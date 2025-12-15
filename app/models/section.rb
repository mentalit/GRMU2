class Section < ApplicationRecord
  belongs_to :aisle
  has_many :levels
  has_many :articles

 
end
