class Article < ApplicationRecord
  belongs_to :store
  validates :artno, presence: true, uniqueness: true

  belongs_to :section, optional: true
  belongs_to :level, optional: true

  before_validation :set_split_rssq

  def effective_height
    # SACRED RULE: Level 00 if DT=1 OR (DT=0 AND (heavy OR rssq >= 45% of palq))
    is_level_00 = dt == 1 || (dt == 0 && (weight_g.to_f > 18_143.7 || rssq.to_f >= (palq.to_f * 0.45)))

    if is_level_00
      (ul_height_gross || 0).to_f
    elsif dt == 0
      # Standard shelving logic for small DT=0 items
      divisor = (mpq.to_i > 0) ? mpq.to_i : 1
      (rssq.to_f / divisor) * (cp_height || 0).to_f
    else
      (cp_height || 0).to_f
    end
  end

   def set_split_rssq
    
    self.split_rssq ||= self.rssq
  end


 
end
