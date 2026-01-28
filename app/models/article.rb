class Article < ApplicationRecord
  belongs_to :store
  validates :artno, presence: true, uniqueness: true

  belongs_to :section, optional: true
  belongs_to :level, optional: true

  before_validation :set_split_rssq
  has_many :placements, dependent: :destroy

  has_many :placements, dependent: :destroy

  before_validation :set_effective_dt


  def qualifies_for_mb?
    split_rssq.to_f >= palq.to_f * 1.6
  end

  BADGE_LABELS = {
    "M" => "Multiple Locations",
    "B" => "Behind",
    "O" => "Opul"
  }.freeze

  def qualifies_for_mb?
    split_rssq.to_f > palq.to_f * 1.50
  end

  def visible_plan_badges
    return [] if plan_badge.blank?

    plan_badge.each_char.select do |badge|
      # O (Opul) always allowed
      next true if badge == "O"

      # M (Multiple) & B (Behind) only if qualifies
      next false if %w[M B].include?(badge) && !qualifies_for_mb?

      true
    end
  end


 def new_locs
  placements
    .includes(section: :aisle, level: {})
    .map do |p|
      [
        p.section.aisle.aisle_num.to_s.rjust(2, "0"),
        p.section.section_num.to_s.rjust(2, "0"),
        p.level.level_num.to_s.rjust(2, "0")
      ].join
    end
    .uniq
end


def new_locs_display
  new_locs.join(" AND ")
end

  # ✅ CSV-safe badge output
  def plan_badges_csv
    visible_plan_badges.join
  end

  def effective_height
    # SACRED RULE: Level 00 if DT=1 OR (DT=0 AND (heavy OR rssq >= 45% of palq))
    is_level_00 = dt == 1 || (dt == 0 && (weight_g.to_f > 18_143.7 || split_rssq.to_f >= (palq.to_f * 0.45)))

    if is_level_00
      (ul_height_gross || 0).to_f
    elsif dt == 0
      # Standard shelving logic for small DT=0 items
      divisor = (mpq.to_i > 0) ? mpq.to_i : 1
      (split_rssq.to_f / divisor) * (cp_height || 0).to_f
    else
      (cp_height || 0).to_f
    end
  end

  def set_split_rssq
  self.split_rssq = rssq if split_rssq.nil?
end

def set_effective_dt
  self.effective_dt ||= dt
end

def total_planned_qty
    placements.sum(:planned_qty).to_f
  end

  def apply_planned_state!
    total = total_planned_qty
    required = rssq.to_f

    if total >= required
      update!(
        planned: true,
        part_planned: false,
        planned_quantity_remainder: nil
      )
    elsif total > 0
      update!(
        planned: false,
        part_planned: true,
        planned_quantity_remainder: required - total
      )
    else
      update!(
        planned: false,
        part_planned: false,
        planned_quantity_remainder: required
      )
    end
  end

  def unassign!
  transaction do
    old_level = level

    # 1. Remove planning state
    placements.destroy_all

    # 2. Detach article physically
    update!(
      level_id: nil,
      section_id: nil
    )

    # 3. Destroy orphaned level (if safe)
    if old_level.present? &&
       old_level.level_num != "00" &&
       old_level.articles.reload.empty?

      old_level.destroy!
    end

    # 4. Update planning flags
    apply_planned_state!
  end
end


 
end
