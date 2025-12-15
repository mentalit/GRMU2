class Article < ApplicationRecord
  belongs_to :store
  validates :artno, presence: true, uniqueness: true

  belongs_to :section, optional: true
end
