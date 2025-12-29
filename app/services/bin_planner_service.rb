# app/services/bin_planner_service.rb

class BinPlannerService
  attr_reader :params, :aisle
  attr_reader :deep_articles, :shallow_articles

  def initialize(aisle:, params:)
    @aisle = aisle
    @params = params.dup
    Rails.logger.debug "[PLANNER] Initializing for Aisle: #{@aisle.aisle_num}"
  end

  def call
    mode = planning_mode
    unless mode.present?
      return { success: false, message: "Planning mode not specified." }
    end

    plan_method = "plan_#{mode.chomp('_mode')}"

    if respond_to?(plan_method, true)
      return send(plan_method, plan_strategy: mode.chomp('_mode').to_sym)
    else
      return { success: false, message: "Invalid planning mode: #{mode}" }
    end
  rescue => e
    Rails.logger.error("[PLANNER] CRITICAL FAILURE: #{e.message}\n#{e.backtrace.join("\n")}")
    return { success: false, message: "Planning failed due to internal error: #{e.message}" }
  end

  private

  def base_section_planner(
  plan_strategy:,
  can_go_on_level_00:,
  width_for:,
  length_for:,
  height_for:, 
  badge_for:
)

  inflated_width_for = lambda do |art, section|
  badge = badge_for.call(art, section)

  base_width =
    if can_go_on_level_00.call(art)
      art.ul_width_gross.to_f
    else
      art.cp_width.to_f
    end

  return base_width unless badge == 'M'

  # 🔥 ONLY M inflates width
  multiplier = art.rssq.to_f / art.palq.to_f
  base_width * multiplier
end

  articles = base_articles_scope.to_a
  Rails.logger.debug "[PLANNER] Master Pool: #{articles.count} articles found."

  @deep_articles = []
  @shallow_articles = []

  articles.each do |art|
    w = width_for.call(art, nil)
    l = length_for.call(art)

    next if w <= 0 || l <= 0

    art.define_singleton_method(:article_width) { w }
    art.define_singleton_method(:article_length) { l }

    if l > 1524
      @deep_articles << art
    else
      @shallow_articles << art
    end
  end

  queue = @shallow_articles + @deep_articles
  available_sections_list = @aisle.sections.order(:section_num).to_a
  planned_count = 0

  section_height_map = available_sections_list.each_with_object({}) do |s, h|
    other_levels_height = s.levels.where.not(level_num: "00").sum(:level_height).to_f
    l00_height = s.levels.where(level_num: "00").maximum(:level_height).to_f
    h[s.id] = s.section_height.to_f - (other_levels_height + l00_height)
  end

  (0..19).each do |level_index|
    break if queue.empty?
    level_num_str = format("%02d", level_index)

    available_sections_list.each do |section|
      break if queue.empty?

      level_candidates =
        if level_index == 0
          queue.select { |a| can_go_on_level_00.call(a) }
        else
          queue.reject { |a| can_go_on_level_00.call(a) }
        end

      next if level_candidates.empty?

      existing_level = section.levels.find_by(level_num: level_num_str)

      if existing_level
        existing_articles = Article.where(section_id: section.id, planned: true).to_a.select do |a|
          level_index == 0 ? can_go_on_level_00.call(a) : !can_go_on_level_00.call(a)
        end

        used_w = existing_articles.sum { |art| inflated_width_for.call(art, section) }

        remaining_width = section.section_width.to_f - used_w
      else
        next if level_index > 0 && section_height_map[section.id] <= 0
        remaining_width = section.section_width.to_f
      end

      planned_for_level = []
      width_cursor = remaining_width

      level_candidates.each do |art|
        next unless art.article_length.to_f <= section.section_depth.to_f

        art_width = inflated_width_for.call(art, section)

        next unless art_width <= width_cursor

        planned_for_level << art
        width_cursor -= art_width
      end

      next if planned_for_level.empty?

      if existing_level
        planned_for_level.each do |art|
          art.update!(
            new_assq: (art.dt == 0 && art.mpq.to_i == 1 ? art.split_rssq : art.new_assq),
            section_id: section.id,
            level: existing_level,
            planned: true,
            plan_badge: badge_for.call(art, section)
          )

          queue.delete(art)
          planned_count += 1
        end

        current_arts = Article.where(section_id: section.id, planned: true).to_a.select do |a|
          level_index == 0 ? can_go_on_level_00.call(a) : !can_go_on_level_00.call(a)
        end

        new_tallest = current_arts.map { |a| height_for.call(a) }.max.to_f
        clr = current_arts.any? { |a| badge_for.call(a, section).present? } ? 254.0 : 127.0
        height_diff = (new_tallest + clr) - existing_level.level_height

        if height_diff > 0
          existing_level.update!(level_height: new_tallest + clr)
          section_height_map[section.id] -= height_diff
        end
      else
        tallest_h = planned_for_level.map { |a| height_for.call(a) }.max.to_f

        clr = planned_for_level.any? { |a| badge_for.call(a, section).present? } ? 254.0 : 127.0
        level_height_needed = tallest_h + clr

        if level_index == 0 || level_height_needed <= section_height_map[section.id]
          new_level = section.levels.create!(
            level_num: level_num_str,
            level_height: level_height_needed
          )

          planned_for_level.each do |art|
            art.update!(
              new_assq: (art.dt == 0 && art.mpq.to_i == 1 ? art.split_rssq : art.new_assq),
              section_id: section.id,
              level: new_level,
              planned: true,
              plan_badge: badge_for.call(art, section)
            )

            queue.delete(art)
            planned_count += 1
          end

          section_height_map[section.id] -= level_height_needed
        end
      end
    end
  end

  { success: true, planned_count: planned_count, unplanned_count: queue.count }
end




  def plan_non_opul(plan_strategy:)
  # Sacred rule preserved exactly as before
  level_00_rule = lambda do |a|
    a.dt == 1 ||
      (a.dt == 0 && (a.weight_g.to_f > 18_143.7 || a.split_rssq.to_f >= (a.palq.to_f * 0.45)))
  end

  # DT=1 special width + badge logic (unchanged)
  dt1_special_width = lambda do |art, section|
    return nil unless art.dt == 1
    return nil unless art.rssq.to_f > art.palq.to_f

    if art.ul_length_gross.to_f * 2 > section.section_depth.to_f
      multiplier = art.rssq.to_f / art.palq.to_f
      {
        
        badge: 'M'
      }
    else
      {
      
        badge: 'B'
      }
    end
  end

  # Width policy (section-aware)
  width_for = lambda do |art, section|
    special = section && dt1_special_width.call(art, section)
    return special[:width] if special && special[:badge] == 'M'

    level_00_rule.call(art) ? art.ul_width_gross.to_f : art.cp_width.to_f
  end

  # Length policy
  length_for = lambda do |art|
    level_00_rule.call(art) ? art.ul_length_gross.to_f : art.cp_length.to_f
  end

  # Badge policy
  badge_for = lambda do |art, section|
    special = section && dt1_special_width.call(art, section)
    special&.dig(:badge)
  end

  height_for = ->(art) { art.effective_height.to_f }

  base_section_planner(
    plan_strategy: plan_strategy,
    can_go_on_level_00: level_00_rule,
    width_for: width_for,
    length_for: length_for,
    height_for: height_for,
    badge_for: badge_for
  )
end

def plan_opul(plan_strategy:)
  opul_blocked_strings = [
    "RTS SS FS Modul",
    "RTS MH Module"
  ]

  is_opul = ->(a) { opul_blocked_strings.include?(a.sal_sol_indic) }

  # 🚫 OPUL can NEVER go on level 00
  can_go_on_level_00 = lambda do |a|
    return false if is_opul.call(a)

    a.dt == 1 ||
      (a.dt == 0 && (
        a.weight_g.to_f > 18_143.7 ||
        a.split_rssq.to_f >= (a.palq.to_f * 0.45)
      ))
  end

  # DT=1 M/B logic (150% gate enforced)
  dt1_special_width = lambda do |art, section|
  {
    width: art.ul_width_gross.to_f * 2,
    badge: art.ul_length_gross.to_f * 2 > section.section_depth.to_f ? 'M' : 'B'
  }
end

  # Width policy
  width_for = lambda do |art, section|
    return art.ul_width_gross.to_f if is_opul.call(art)

    special = section && dt1_special_width.call(art, section)
    return special[:width] if special

    can_go_on_level_00.call(art) ? art.ul_width_gross.to_f : art.cp_width.to_f
  end

  # Length policy
  length_for = lambda do |art|
    return art.ul_length_gross.to_f if is_opul.call(art)

    can_go_on_level_00.call(art) ? art.ul_length_gross.to_f : art.cp_length.to_f
  end

  # Badge policy
  badge_for = lambda do |art, section|
    badges = []

    special = section && dt1_special_width.call(art, section)
    badges << special[:badge] if special&.dig(:badge)

    badges << 'O' if is_opul.call(art)

    badges.presence&.join
  end

  # ===============================
  # 🔥 OPUL HEIGHT + WIDTH GREEDY
  # ===============================

  height_bucket_mm = 50  # ← FIX: local variable, NOT constant

  original_scope = base_articles_scope.to_a

  non_opul_articles = original_scope.reject { |a| is_opul.call(a) }
  opul_articles     = original_scope.select { |a| is_opul.call(a) }

  # Bucket OPUL articles by similar height
  buckets = opul_articles.group_by do |a|
    (a.effective_height.to_f / height_bucket_mm).floor
  end

  # Tallest buckets first, width-greedy inside each bucket
  sorted_opul =
    buckets.keys.sort.reverse.flat_map do |bucket|
      buckets[bucket].sort_by { |a| -width_for.call(a, nil) }
    end

  # Rebuild article order:
  # non-OPUL first (eligible for level 00)
  # OPUL after (levels 01+ only)
  define_singleton_method(:base_articles_scope) do
    non_opul_articles + sorted_opul
  end

  height_for = ->(art) { art.effective_height.to_f }

  base_section_planner(
    plan_strategy: plan_strategy,
    can_go_on_level_00: can_go_on_level_00,
    width_for: width_for,
    length_for: length_for,
     height_for: height_for,
    badge_for: badge_for
  )
end





 def plan_countertop(plan_strategy:)
  # ============================
  # COUNTERTOP RULES
  # ============================

  # Level 00 enforcement
  can_go_on_level_00 = lambda do |art|
    art.dt == 1 || art.weight_g.to_f > 27_215.5
  end

  # Width policy
  width_for = lambda do |art, _section|
    if art.dt == 1
      art.ul_width_gross.to_f
    else
      art.cp_width.to_f
    end
  end

  # Length policy
  length_for = lambda do |art|
    if art.dt == 1
      art.ul_length_gross.to_f
    else
      art.cp_length.to_f
    end
  end

  # Height policy
  height_for = lambda do |art|
    if art.dt == 1
      art.ul_height_gross.to_f
    else
      art.cp_height.to_f
    end
  end

  # No badges for countertop
  badge_for = ->(_art, _section) { nil }

  base_section_planner(
    plan_strategy: plan_strategy,
    can_go_on_level_00: can_go_on_level_00,
    width_for: width_for,
    length_for: length_for,
    height_for: height_for,
    badge_for: badge_for
  )
end


 def plan_voss(plan_strategy:)
  # VOSS rules: CP-only, never level 00, no badges

  can_go_on_level_00 = ->(_art) { false }

  width_for = ->(art, _section) do
    art.cp_width.to_f
  end

  length_for = ->(art) do
    art.cp_length.to_f
  end

  badge_for = ->(_art, _section) { nil }

  height_for = ->(art) { art.effective_height.to_f }

  base_section_planner(
      plan_strategy: plan_strategy,
      can_go_on_level_00: can_go_on_level_00,
      width_for: width_for,
      length_for: length_for, 
      height_for: height_for,
      badge_for: badge_for
    )
  end

  def plan_pallet(plan_strategy:)
  # PALLET rules: UL-only, never level 00, no badges

  can_go_on_level_00 = ->(_art) { false }

  width_for = ->(art, _section) do
    art.ul_width_gross.to_f
  end

  length_for = ->(art) do
    art.ul_length_gross.to_f
  end

  badge_for = ->(_art, _section) { nil }

  height_for = ->(art) { art.effective_height.to_f }

  base_section_planner(
    plan_strategy: plan_strategy,
    can_go_on_level_00: can_go_on_level_00,
    width_for: width_for,
    length_for: length_for,
    height_for: height_for,
    badge_for: badge_for
  )
end

  def base_articles_scope
    scope = @aisle.pair.store.articles
    scope = scope.where('artname_unicode ILIKE ?', "#{name_prefix}%") if name_prefix
    scope = apply_pa_hfb_filter(scope)

    if low_expsale_only?
      scope = scope.where('expsale < 5')
    elsif high_expsale_only?
      scope = scope.where('expsale > 5')
      scope = scope.where(dt: 1) if high_expsale_require_dt1?
    end

    scope = scope.where(planned: [false, nil])

  case planning_mode
    when 'voss_mode'
      scope = apply_voss_gates(scope)
    when 'pallet_mode'
      scope = apply_pallet_gates(scope)
  end

    scope
  end

  def planning_mode; @params[:mode]; end
  def name_prefix; @params[:name_prefix].presence; end
  def low_expsale_only?; @params[:low_expsale_only].present?; end
  def high_expsale_only?; @params[:high_expsale_only].present?; end
  def high_expsale_require_dt1?; @params[:high_expsale_require_dt1].present?; end

  def apply_pa_hfb_filter(scope)
    val = @params[:filter_value].presence
    return scope unless val
    case @params[:filter_type]
    when 'PA' then scope.where(pa: val)
    when 'HFB' then scope.where(hfb: val)
    else scope
    end
  end

  def apply_voss_gates(scope)
    scope = scope.where(dt: 0)
    scope = scope.where('cp_height <= ?', @params[:voss_cp_height_max]) if @params[:voss_cp_height_max].present?
    scope = scope.where('cp_length <= ?', @params[:voss_cp_length_max]) if @params[:voss_cp_length_max].present?
    scope = scope.where('cp_width <= ?', @params[:voss_cp_width_max]) if @params[:voss_cp_width_max].present?
    scope = scope.where('split_rssq <= ?', @params[:voss_rssq_max]) if @params[:voss_rssq_max].present?
    scope = scope.where('expsale <= ?', @params[:voss_expsale_max]) if @params[:voss_expsale_max].present?
    scope = scope.where('weight_g <= ?', @params[:voss_weight_g_max]) if @params[:voss_weight_g_max].present?
    scope
  end

 def apply_pallet_gates(scope)
  scope = scope.where(dt: 1)

  scope = scope.where('ul_height_gross <= ?', @params[:voss_ul_height_max]) if @params[:voss_ul_height_max].present?
  scope = scope.where('ul_length_gross <= ?', @params[:voss_ul_length_max]) if @params[:voss_ul_length_max].present?
  scope = scope.where('ul_width_gross  <= ?', @params[:voss_ul_width_max])  if @params[:voss_ul_width_max].present?

  scope = scope.where('split_rssq <= ?', @params[:voss_rssq_max])     if @params[:voss_rssq_max].present?
  scope = scope.where('expsale <= ?',    @params[:voss_expsale_max])  if @params[:voss_expsale_max].present?
  scope = scope.where('weight_g <= ?',   @params[:voss_weight_g_max]) if @params[:voss_weight_g_max].present?

  scope
end
end