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
      return send(plan_method)
    else
      return { success: false, message: "Invalid planning mode: #{mode}" }
    end
  rescue => e
    Rails.logger.error("[PLANNER] CRITICAL FAILURE: #{e.message}\n#{e.backtrace.join("\n")}")
    return { success: false, message: "Planning failed due to internal error: #{e.message}" }
  end

  private

  def base_section_planner(plan_strategy:)
    # 1. Define the SACRED RULE (Updated to 45%)
    level_00_rule = lambda do |a|
      a.dt == 1 || (a.dt == 0 && (a.weight_g.to_f > 18_143.7 || a.split_rssq.to_f >= (a.palq.to_f * 0.45)))
    end

    # Helper to get width/length using Pallet (ul_) measurements if the rule is met
    get_art_width = lambda do |a|
      level_00_rule.call(a) ? a.ul_width_gross.to_f : a.cp_width.to_f
    end

    get_art_length = lambda do |a|
      level_00_rule.call(a) ? a.ul_length_gross.to_f : a.cp_length.to_f
    end

    articles = base_articles_scope.to_a
    Rails.logger.debug "[PLANNER] Master Pool: #{articles.count} articles found."

    @deep_articles = []
    @shallow_articles = []

    articles.each do |art|
      w = get_art_width.call(art)
      l = get_art_length.call(art)
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

        level_candidates = if level_index == 0
          queue.select { |a| level_00_rule.call(a) }
        else
          queue.select { |a| a.dt == 0 && !level_00_rule.call(a) }
               .sort_by { |a| a.weight_g.to_f }
        end
        next if level_candidates.empty?

        existing_level = section.levels.find_by(level_num: level_num_str)
        
        if existing_level
          existing_articles = Article.where(section_id: section.id, planned: true).to_a.select do |a|
            level_index == 0 ? level_00_rule.call(a) : (a.dt == 0 && !level_00_rule.call(a))
          end
          used_w = existing_articles.sum { |art| get_art_width.call(art) }
          remaining_width = section.section_width.to_f - used_w
        else
          next if level_index > 0 && section_height_map[section.id] <= 0
          remaining_width = section.section_width.to_f
        end

        planned_for_level = []
        width_cursor = remaining_width

        level_candidates.each do |art|
          next unless art.article_length.to_f <= section.section_depth.to_f
          next unless art.article_width.to_f <= width_cursor

          planned_for_level << art
          width_cursor -= art.article_width.to_f
        end

        if planned_for_level.any?
          if existing_level
            planned_for_level.each do |art|
              art.update!(new_assq: art.split_rssq) if art.dt == 0 && art.mpq.to_i == 1
              art.update!(section_id: section.id, planned: true)
              queue.delete(art)
              planned_count += 1
            end

            current_arts = Article.where(section_id: section.id, planned: true).to_a.select do |a|
              level_index == 0 ? level_00_rule.call(a) : (a.dt == 0 && !level_00_rule.call(a))
            end

            new_tallest = current_arts.map(&:effective_height).max.to_f
            clr = current_arts.any? { |a| a.dt == 1 || (a.dt == 0 && a.split_rssq.to_f >= (a.palq.to_f * 0.45)) } ? 254.0 : 127.0
            height_diff = (new_tallest + clr) - existing_level.level_height
            
            if height_diff > 0
              existing_level.update!(level_height: new_tallest + clr)
              section_height_map[section.id] -= height_diff
            end
          else
            tallest_h = planned_for_level.map(&:effective_height).max.to_f
            clr = planned_for_level.any? { |a| a.dt == 1 || (a.dt == 0 && a.split_rssq.to_f >= (a.palq.to_f * 0.45)) } ? 254.0 : 127.0
            level_height_needed = tallest_h + clr

            if level_index == 0 || level_height_needed <= section_height_map[section.id]
              section.levels.create!(level_num: level_num_str, level_height: level_height_needed)
              planned_for_level.each do |art|
                art.update!(new_assq: art.split_rssq) if art.dt == 0 && art.mpq.to_i == 1
                art.update!(section_id: section.id, planned: true)
                queue.delete(art)
                planned_count += 1
              end
              section_height_map[section.id] -= level_height_needed
            end
          end
        end
      end
    end

    { success: true, planned_count: planned_count, unplanned_count: queue.count }
  end

  def plan_non_opul; base_section_planner(plan_strategy: :non_opul); end
  def plan_opul; base_section_planner(plan_strategy: :opul); end
  def plan_countertop; base_section_planner(plan_strategy: :countertop); end
  def plan_voss; base_section_planner(plan_strategy: :voss_assignment); end
  def plan_pallet; base_section_planner(plan_strategy: :pallet_assignment); end

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
    scope = apply_voss_gates(scope) if planning_mode == 'voss_mode'
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
    scope = scope.where('split_rssq <= ?', @params[:voss_split_rssq_max]) if @params[:voss_split_rssq_max].present?
    scope = scope.where('expsale <= ?', @params[:voss_expsale_max]) if @params[:voss_expsale_max].present?
    scope = scope.where('weight_g <= ?', @params[:voss_weight_g_max]) if @params[:voss_weight_g_max].present?
    scope
  end
end