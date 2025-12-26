class Level < ApplicationRecord
  belongs_to :section

  has_many :articles, dependent: :nullify
end
