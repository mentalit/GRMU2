# app/services/bin_planner_service.rb
class BinPlannerService
  attr_reader :params, :aisle

  def initialize(aisle:, params:)
    @aisle = aisle
    @params = params.dup
    Rails.logger.debug "[PLANNER] Initializing for Aisle: #{@aisle.aisle_num}"
  end

  def call
    mode = planning_mode
    return { success: false, message: "Planning mode not specified." } unless mode.present?

    plan_method = "plan_#{mode.chomp('_mode')}"
    return { success: false, message: "Invalid mode: #{mode}" } unless respond_to?(plan_method, true)

    send(plan_method, plan_strategy: mode.chomp('_mode').to_sym)
  rescue => e
    Rails.logger.error("[PLANNER] CRITICAL FAILURE: #{e.message}\n#{e.backtrace.join("\n")}")
    { success: false, message: "Planning failed: #{e.message}" }
  end

  private


  

  def planned_assq_for(art)
    art.split_rssq.to_f
  end

  # --- Core Planning Engine ---

  def planner_debug?
      # Enable with params[:debug] OR ENV var
      @params[:debug].present? || ENV["PLANNER_DEBUG"] == "1"
    end

    def plog(msg)
      return unless planner_debug?
      Rails.logger.debug("[PLANNER-DBG] #{msg}")
    end

    def summarize_widths(arts, section, effective_width_for)
      ws = arts.map { |a| effective_width_for.call(a, section).to_f }.select { |w| w > 0 }.sort
      return "none" if ws.empty?

      min = ws.first
      max = ws.last
      mid = ws[ws.length / 2]
      top = ws.last(10).reverse.map { |w| w.round(1) }.join(", ")
      "count=#{ws.length} min=#{min.round(1)} median=#{mid.round(1)} max=#{max.round(1)} top10=[#{top}]"
    end

 def base_section_planner(
  plan_strategy:,
  can_go_on_level_00:,
  width_for:,
  length_for:,
  height_for:,
  badge_for:,
  allow_dt1_on_non_00: nil
)
  # 🔧 SINGLE SOURCE OF TRUTH: badge logic
  effective_badge_for = lambda do |art, section|
  return nil unless section

  # 🚫 HARD GATE — small overruns NEVER badge
  return nil if art.split_rssq.to_f < (art.palq.to_f * 1.7)

  badge_for.call(art, section)
end

  # 🔧 SINGLE SOURCE OF TRUTH: width logic
  effective_width_for = lambda do |art, section|
  base_w = width_for.call(art, section)
  return 0.0 unless base_w.to_f > 0

  # 🔴 HARD RSSQ OVERRIDE — applies to ALL badges
  if art.split_rssq.to_f > art.palq.to_f * 1.3
    return base_w.to_f * 2
  end

  badge = effective_badge_for.call(art, section)
  return base_w unless badge == "M"

  mult = (art.split_rssq.to_f / art.palq.to_f).ceil
  return 0.0 if mult <= 0

  art.ul_width_gross.to_f * mult
end


  queue = prepare_article_queue(width_for, length_for)
  sections = @aisle.sections.order(:section_num).to_a
  planned_count = 0

  # ------------------------------------------------------------
  # PHASE 1 — GLOBAL LEVEL 00
  # ------------------------------------------------------------
  level_00_candidates = queue.select { |a| can_go_on_level_00.call(a) }

  section_bins = sections.map do |s|
    level_00 = s.levels.find_by(level_num: "00")
    used_w = level_00 ? Placement.where(level_id: level_00.id).sum(:width_used).to_f : 0.0

    {
      section: s,
      remaining_w: s.section_width.to_f - used_w,
      items: []
    }
  end

  sorted_00 = level_00_candidates.sort_by { |a| -effective_width_for.call(a, nil).to_f }

  sorted_00.each do |art|
    next if effective_width_for.call(art, nil).to_f <= 0

    bin = section_bins.find do |b|
      w = effective_width_for.call(art, b[:section]).to_f
      w > 0 &&
        w <= b[:remaining_w] &&
        art.article_length.to_f <= b[:section].section_depth.to_f
    end
    next unless bin

    bin[:items] << art
    bin[:remaining_w] -= effective_width_for.call(art, bin[:section]).to_f
  end

  section_bins.each do |bin|
    next if bin[:items].empty?

    section = bin[:section]
    level = section.levels.find_or_create_by!(level_num: "00")

    bin[:items].each do |art|
      badge = effective_badge_for.call(art, section)

      if plan_strategy == :opul && badge == "O"
        raise "OPUL article placed on level 00!"
      end

      Placement.create!(
        article: art,
        section: section,
        level: level,
        planned_qty: planned_assq_for(art),
        badge: badge,
        width_used: effective_width_for.call(art, section).to_f
      )

      art.update!(section_id: section.id, level_id: level.id)
      art.apply_planned_state!
      queue.delete(art)
      planned_count += 1
    end

    arts = Placement.where(level_id: level.id).includes(:article).map(&:article)
    new_h = arts.map { |a| height_for.call(a) }.max.to_f
    clr = arts.any? { |a| effective_badge_for.call(a, section).present? } ? 254.0 : 127.0
    level.update!(level_height: new_h + clr)
  end

  # ------------------------------------------------------------
  # PHASE 2 — LEVELS 01+
  # ------------------------------------------------------------
  section_height_map =
    sections.each_with_object({}) do |s, h|
      l00 = s.levels.find_by(level_num: "00")&.level_height.to_f
      other = s.levels.where.not(level_num: "00").sum(:level_height).to_f
      h[s.id] = s.section_height.to_f - (l00 + other)
    end

  (1..19).each do |idx|
    break if queue.empty?
    level_str = format("%02d", idx)

    eligible =
      if plan_strategy == :non_opul
        queue.reject { |a| a.dt == 1 }
      elsif allow_dt1_on_non_00
        queue.select { |a| allow_dt1_on_non_00.call(a) }
      else
        queue
      end

    next if eligible.empty?

    bins =
      sections.map do |section|
        level = section.levels.find_by(level_num: level_str)

        if level
          used_w = Placement.where(level_id: level.id).sum(:width_used).to_f
          remaining_w = section.section_width.to_f - used_w
        else
          next if section_height_map[section.id] <= 0
          remaining_w = section.section_width.to_f
        end

        {
          section: section,
          level: level,
          remaining_w: remaining_w,
          items: []
        }
      end.compact

    eligible.sort_by { |a| -effective_width_for.call(a, nil).to_f }.each do |art|
      next if effective_width_for.call(art, nil).to_f <= 0

      bin = bins.find do |b|
        w = effective_width_for.call(art, b[:section]).to_f
        w > 0 &&
          w <= b[:remaining_w] &&
          art.article_length.to_f <= b[:section].section_depth.to_f
      end
      next unless bin

      bin[:items] << art
      bin[:remaining_w] -= effective_width_for.call(art, bin[:section]).to_f
    end

    bins.each do |bin|
      next if bin[:items].empty?

      section = bin[:section]
      level = bin[:level] || section.levels.create!(level_num: level_str, level_height: 0)

      bin[:items].each do |art|
        if allow_dt1_on_non_00 && art.dt == 1 && !allow_dt1_on_non_00.call(art)
          raise "DT=1 article illegally placed on non-00 level (#{art.id})"
        end

        Placement.create!(
          article: art,
          section: section,
          level: level,
          planned_qty: planned_assq_for(art),
          badge: effective_badge_for.call(art, section),
          width_used: effective_width_for.call(art, section).to_f
        )

        art.update!(section_id: section.id, level_id: level.id)
        art.apply_planned_state!
        queue.delete(art)
        planned_count += 1
      end

      arts = Placement.where(level_id: level.id).includes(:article).map(&:article)
      new_h = arts.map { |a| height_for.call(a) }.max.to_f
      clr = arts.any? { |a| effective_badge_for.call(a, section).present? } ? 254.0 : 127.0

      diff = (new_h + clr) - level.level_height
      if diff > 0
        level.update!(level_height: new_h + clr)
        section_height_map[section.id] -= diff
      end
    end
  end

  { success: true, planned_count: planned_count, unplanned_count: queue.size }
end







  # --- Strategy Definitions ---

  def plan_pallet(plan_strategy:)
    can_go_00 = lambda do |a|
      a.dt == 1 || (a.dt == 0 && (a.weight_g.to_f > 18_143.7 || a.split_rssq.to_f >= (a.palq.to_f * 0.45)))
    end

    width_for = lambda do |art, section|
      if section && art.dt == 1 && art.split_rssq.to_f > art.palq.to_f && (art.ul_length_gross.to_f * 2 > section.section_depth.to_f)
        return art.ul_width_gross.to_f # Multiplier applied in effective_width_for via 'M' badge
      end
      can_go_00.call(art) ? art.ul_width_gross.to_f : art.cp_width.to_f
    end

    badge_for = lambda do |art, section|
  return nil unless section &&
                    art.split_rssq.to_f > art.palq.to_f

  art.ul_length_gross.to_f * 2 > section.section_depth.to_f ? "M" : "B"
end


    base_section_planner(
      plan_strategy: plan_strategy,
      can_go_on_level_00: can_go_00,
      width_for: width_for,
      length_for: ->(a) { can_go_00.call(a) ? a.ul_length_gross.to_f : a.cp_length.to_f },
      height_for: ->(a) { a.effective_height.to_f },
      badge_for: badge_for
    )
  end



  def plan_countertop(plan_strategy:)
  heavy_weight = 27_215.5
  max_non_l00_level_height = 1092.2

  can_go_on_level_00 = lambda do |art|
    art.dt == 1 || art.weight_g.to_f > heavy_weight
  end

  width_for = lambda do |art, _section|
    art.dt == 1 ? art.ul_width_gross.to_f : art.cp_width.to_f
  end

  length_for = lambda do |art|
    art.dt == 1 ? art.ul_length_gross.to_f : art.cp_length.to_f
  end

  height_for = lambda do |art|
    art.dt == 1 ? art.ul_height_gross.to_f : art.cp_height.to_f
  end

  badge_for = ->(_art, _section) { nil }

  define_singleton_method(:base_articles_scope) do
    scope = super()

    scope.select do |art|
      if can_go_on_level_00.call(art)
        true
      else
        height_for.call(art) < max_non_l00_level_height
      end
    end
  end

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
  # VOSS rules: CP-only, never level 00, no badges, DT == 0 ONLY

  can_go_on_level_00 = ->(_art) { false }

  width_for  = ->(art, _section) { art.cp_width.to_f }
  length_for = ->(art) { art.cp_length.to_f }
  height_for = ->(art) { art.cp_height.to_f }
  badge_for  = ->(_art, _section) { nil }

  # 🔒 HARD ENFORCEMENT: DT == 0 ONLY (VOSS)
  define_singleton_method(:base_articles_scope) do
    super().where(dt: 0)
  end

  base_section_planner(
    plan_strategy: plan_strategy,
    can_go_on_level_00: can_go_on_level_00,
    width_for: width_for,
    length_for: length_for,
    height_for: height_for,
    badge_for: badge_for
  )
end




  def plan_opul(plan_strategy:)
    opul_tags = ["RTS SS FS Modul", "RTS MH Module"]
    is_opul = ->(a) { opul_tags.include?(a.sal_sol_indic) }

    can_go_00 = lambda do |a|
      return false if is_opul.call(a) # OPUL items never on level 00
      a.dt == 1 || (a.dt == 0 && (a.weight_g.to_f > 18_143.7 || a.split_rssq.to_f >= (a.palq.to_f * 0.45)))
    end

    width_for = lambda do |art, section|
      if section && art.dt == 1 && art.split_rssq.to_f > art.palq.to_f && (art.ul_length_gross.to_f * 2 > section.section_depth.to_f)
        return art.ul_width_gross.to_f # Multiplier applied in effective_width_for via 'M' badge
      end
      can_go_00.call(art) ? art.ul_width_gross.to_f : art.cp_width.to_f
    end

   badge_for = lambda do |art, section|
  return nil unless section &&
                    art.split_rssq.to_f > art.palq.to_f

  art.ul_length_gross.to_f * 2 > section.section_depth.to_f ? "M" : "B"
end


    base_section_planner(
      plan_strategy: plan_strategy,
      can_go_on_level_00: can_go_00,
      width_for: width_for,
      length_for: ->(a) { is_opul.call(a) || can_go_00.call(a) ? a.ul_length_gross.to_f : a.cp_length.to_f },
      height_for: ->(a) { a.effective_height.to_f },
      badge_for: badge_for
    )
  end

  def plan_non_opul(plan_strategy:)
    can_go_00 = lambda do |a|
      a.dt == 1 || (a.dt == 0 && (a.weight_g.to_f > 18_143.7 || a.split_rssq.to_f >= (a.palq.to_f * 0.45)))
    end

    width_for = lambda do |art, section|
      if section && art.dt == 1 && art.split_rssq.to_f > art.palq.to_f && (art.ul_length_gross.to_f * 2 > section.section_depth.to_f)
        return art.ul_width_gross.to_f # Multiplier applied in effective_width_for via 'M' badge
      end
      can_go_00.call(art) ? art.ul_width_gross.to_f : art.cp_width.to_f
    end

    badge_for = lambda do |art, section|
  return nil unless section &&
                    art.split_rssq.to_f > art.palq.to_f

  art.ul_length_gross.to_f * 2 > section.section_depth.to_f ? "M" : "B"
end

    base_section_planner(
      plan_strategy: plan_strategy,
      can_go_on_level_00: can_go_00,
      width_for: width_for,
      length_for: ->(a) { can_go_00.call(a) ? a.ul_length_gross.to_f : a.cp_length.to_f },
      height_for: ->(a) { a.effective_height.to_f },
      badge_for: badge_for
    )
  end

  # --- Helper Methods ---

  def prepare_article_queue(width_fn, length_fn)
    base_articles_scope.to_a.each_with_object([[], []]) do |art, (sh, dp)|
      w = width_fn.call(art, nil)
      l = length_fn.call(art)
      next if w.to_f <= 0 || l.to_f <= 0

      art.define_singleton_method(:article_width) { w }
      art.define_singleton_method(:article_length) { l }
      l > 1524 ? dp << art : sh << art
    end.flatten
  end

  def base_articles_scope
    scope = @aisle.pair.store.articles.where(planned: [false, nil])
    scope = scope.where("artname_unicode ILIKE ?", "#{name_prefix}%") if name_prefix
    scope = apply_pa_hfb_filter(scope)

    if low_expsale_only?
      scope = scope.where("expsale < 5")
    elsif high_expsale_only?
      scope = scope.where("expsale > 5")
      scope = scope.where(dt: 1) if high_expsale_require_dt1?
    end

    case planning_mode
    when "voss_mode" then apply_voss_gates(scope)
    when "pallet_mode" then apply_pallet_gates(scope)
    else scope
    end
  end

  def planning_mode = @params[:mode]
  def name_prefix = @params[:name_prefix].presence
  def low_expsale_only? = @params[:low_expsale_only].present?
  def high_expsale_only? = @params[:high_expsale_only].present?
  def high_expsale_require_dt1? = @params[:high_expsale_require_dt1].present?

  def apply_pa_hfb_filter(scope)
    type, val = @params.values_at(:filter_type, :filter_value)
    return scope unless val.present? && %w[PA HFB].include?(type)
    scope.where(type.downcase.to_sym => val)
  end

  def apply_voss_gates(scope)
  scope = scope.where(dt: 0)

  scope = scope.where("cp_height <= ?", @params[:voss_cp_height_max]) if @params[:voss_cp_height_max].present?
  scope = scope.where("cp_length <= ?", @params[:voss_cp_length_max]) if @params[:voss_cp_length_max].present?
  scope = scope.where("cp_width  <= ?", @params[:voss_cp_width_max])  if @params[:voss_cp_width_max].present?

  scope = scope.where("split_rssq <= ?", @params[:voss_rssq_max])     if @params[:voss_rssq_max].present?
  scope = scope.where("expsale    <= ?", @params[:voss_expsale_max])  if @params[:voss_expsale_max].present?
  scope = scope.where("weight_g   <= ?", @params[:voss_weight_g_max]) if @params[:voss_weight_g_max].present?

  scope
end


  def apply_pallet_gates(scope)
    scope.where(dt: 1).where("ul_height_gross <= ? AND ul_length_gross <= ? AND ul_width_gross <= ?", 
      @params[:voss_ul_height_max], @params[:voss_ul_length_max], @params[:voss_ul_width_max])
  end
end