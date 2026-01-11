class Placement < ApplicationRecord
  belongs_to :article
  belongs_to :section, optional: true
  belongs_to :level, optional: true
end