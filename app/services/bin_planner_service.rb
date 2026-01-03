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

  def base_section_planner(plan_strategy:, can_go_on_level_00:, width_for:, length_for:, height_for:, badge_for:)
  # 🔧 SINGLE SOURCE OF TRUTH: width logic
  effective_width_for = lambda do |art, section|
    base_w = width_for.call(art, section)
    return 0.0 unless base_w.to_f > 0

    badge = badge_for.call(art, section)
    return base_w unless badge&.include?("M")

    mult = art.rssq.to_f / art.palq.to_f
    base_w * (mult > 0 ? mult : 1.0)
  end

  queue    = prepare_article_queue(width_for, length_for)
  sections = @aisle.sections.order(:section_num).to_a
  planned_count = 0

  # ------------------------------------------------------------
  # PHASE 1 — GLOBAL LEVEL 00 (BOX A)
  # ------------------------------------------------------------
  level_00_candidates = queue.select { |a| can_go_on_level_00.call(a) }

  section_bins = sections.map do |s|
    {
      section: s,
      remaining_w: s.section_width.to_f,
      items: []
    }
  end

  sorted_00 =
    level_00_candidates.sort_by do |a|
      -effective_width_for.call(a, nil).to_f
    end

  sorted_00.each do |art|
  w = effective_width_for.call(art, nil).to_f
  next if w <= 0

  bin = section_bins.find { |b| b[:remaining_w] >= w }
  next unless bin

  bin[:items] << art
  bin[:remaining_w] -= w
end

  # Persist level 00
  section_bins.each do |bin|
    next if bin[:items].empty?

    section = bin[:section]
    level   = section.levels.find_or_create_by!(
      level_num: "00",
      level_height: 0
    )

    bin[:items].each do |art|
      badge = badge_for.call(art, section)

      if plan_strategy == :opul && badge&.include?("O")
        raise "OPUL article placed on level 00!"
      end

      art.update!(
        new_assq: (art.dt == 0 && art.mpq.to_i == 1 ? art.split_rssq : art.new_assq),
        section_id: section.id,
        level_id: level.id,
        planned: true,
        plan_badge: badge
      )

      queue.delete(art)
      planned_count += 1
    end

    # finalize level height
    current = Article.where(level_id: level.id, planned: true)
    new_h   = current.map { |a| height_for.call(a) }.max.to_f
    clr     = current.any? { |a| badge_for.call(a, section).present? } ? 254.0 : 127.0
    level.update!(level_height: new_h + clr)
  end

  # ------------------------------------------------------------
  # PHASE 2 — LEVELS 01+ (UNCHANGED LOGIC)
  # ------------------------------------------------------------
  section_height_map = sections.each_with_object({}) do |s, h|
    l00_h   = s.levels.find_by(level_num: "00")&.level_height.to_f
    other_h = s.levels.where.not(level_num: "00").sum(:level_height).to_f
    h[s.id] = s.section_height.to_f - (l00_h + other_h)
  end

  (1..19).each do |level_idx|
    break if queue.empty?
    level_str = format("%02d", level_idx)

    sections.each do |section|
      break if queue.empty?

      eligible = queue.reject { |a| can_go_on_level_00.call(a) }
      next if eligible.empty?

      existing_level = section.levels.find_by(level_num: level_str)

      if existing_level
        used_w = Article.where(level_id: existing_level.id, planned: true)
                        .sum { |a| effective_width_for.call(a, section) }
        remaining_w = section.section_width.to_f - used_w
      else
        next if section_height_map[section.id] <= 0
        remaining_w = section.section_width.to_f
      end

      planned_this_run = []
      cursor = remaining_w

      eligible.sort_by { |a| -effective_width_for.call(a, section).to_f }.each do |art|
        w = effective_width_for.call(art, section).to_f
        next if w <= 0 || w > cursor
        next if art.article_length.to_f > section.section_depth.to_f

        planned_this_run << art
        cursor -= w
      end

      next if planned_this_run.empty?

      target_level = existing_level || section.levels.create!(level_num: level_str, level_height: 0)

      planned_this_run.each do |art|
        badge = badge_for.call(art, section)

        art.update!(
          new_assq: (art.dt == 0 && art.mpq.to_i == 1 ? art.split_rssq : art.new_assq),
          section_id: section.id,
          level_id: target_level.id,
          planned: true,
          plan_badge: badge
        )

        queue.delete(art)
        planned_count += 1
      end

      current = Article.where(level_id: target_level.id, planned: true)
      new_h   = current.map { |a| height_for.call(a) }.max.to_f
      clr     = current.any? { |a| badge_for.call(a, section).present? } ? 254.0 : 127.0
      diff    = (new_h + clr) - target_level.level_height

      if diff > 0
        target_level.update!(level_height: new_h + clr)
        section_height_map[section.id] -= diff
      end
    end
  end

  { success: true, planned_count: planned_count, unplanned_count: queue.size }
end



  # --- Strategy Definitions ---

  def plan_opul(plan_strategy:)
    opul_tags = ["RTS SS FS Modul", "RTS MH Module"]
    is_opul = ->(a) { opul_tags.include?(a.sal_sol_indic) }

    can_go_00 = lambda do |a|
      return false if is_opul.call(a) # OPUL items never on level 00
      a.dt == 1 || (a.dt == 0 && (a.weight_g.to_f > 18_143.7 || a.split_rssq.to_f >= (a.palq.to_f * 0.45)))
    end

    width_for = lambda do |art, section|
      return art.ul_width_gross.to_f if is_opul.call(art) # Always Gross for OPUL
      
      # Handle Multiplier Badge 'M' for DT1
      if section && art.dt == 1 && (art.ul_length_gross.to_f * 2 > section.section_depth.to_f)
        return art.ul_width_gross.to_f * 2
      end

      can_go_00.call(art) ? art.ul_width_gross.to_f : art.cp_width.to_f
    end

    badge_for = lambda do |art, section|
      b = []
      b << "O" if is_opul.call(art)
      if section && art.dt == 1
         b << (art.ul_length_gross.to_f * 2 > section.section_depth.to_f ? "M" : "B")
      end
      b.join.presence
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
      if section && art.dt == 1 && art.rssq.to_f > art.palq.to_f && (art.ul_length_gross.to_f * 2 > section.section_depth.to_f)
        return art.ul_width_gross.to_f # Multiplier applied in effective_width_for via 'M' badge
      end
      can_go_00.call(art) ? art.ul_width_gross.to_f : art.cp_width.to_f
    end

    badge_for = lambda do |art, section|
      return nil unless section && art.dt == 1 && art.rssq.to_f > art.palq.to_f
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
    scope.where(dt: 0).where("cp_height <= ? AND cp_length <= ? AND cp_width <= ?", 
      @params[:voss_cp_height_max], @params[:voss_cp_length_max], @params[:voss_cp_width_max])
  end

  def apply_pallet_gates(scope)
    scope.where(dt: 1).where("ul_height_gross <= ? AND ul_length_gross <= ? AND ul_width_gross <= ?", 
      @params[:voss_ul_height_max], @params[:voss_ul_length_max], @params[:voss_ul_width_max])
  end
end