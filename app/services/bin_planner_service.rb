# app/services/bin_planner_service.rb

class BinPlannerService
  attr_reader :params, :aisle
  # Readers for the sorted lists
  attr_reader :deep_articles, :shallow_articles

  def initialize(aisle:, params:)
    @aisle = aisle
    @params = params.dup
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
    Rails.logger.error("BinPlannerService failed: #{e.message}")
    return { success: false, message: "Planning failed due to internal error: #{e.message}" }
  end

  private

  # --- COMMON PLANNING ENTRY POINT ---

  def base_section_planner(plan_strategy:)
    # 1. Get the filtered articles and convert to array
    articles = base_articles_scope.to_a
    @deep_articles = []
    @shallow_articles = []
    skipped_count = 0

    # 2. Calculate dimensions and sort into @deep and @shallow
    articles.each do |art|
      if art.dt == 1 || (art.dt == 0 && (art.rssq > art.palq))
        calculated_width = art.ul_width_gross
        calculated_length = art.ul_length_gross
      else
        calculated_width = art.cp_width
        calculated_length = art.cp_length
      end

      unless calculated_length.is_a?(Numeric) && calculated_width.is_a?(Numeric)
        skipped_count += 1
        next
      end

      art.define_singleton_method(:article_width) { calculated_width }
      art.define_singleton_method(:article_length) { calculated_length }

      if art.article_length > 1524
        @deep_articles << art
      else
        @shallow_articles << art
      end
    end

    # 3. Create the master queue (shallow articles first for better density)
    queue = @shallow_articles + @deep_articles

    # 4. Get available sections (empty sections only)
    available_sections = @aisle.sections
                              .left_joins(:articles)
                              .group('sections.id')
                              .having('count(articles.id) = 0')
                              .order(:section_num)

    planned_count = 0

    # ------------------------------------------------------------
    # 5. DYNAMIC LEVEL PLANNING (00..19) WITH HARD HEIGHT CONSTRAINT
    # ------------------------------------------------------------
    available_sections.each do |section|
      # If the section is empty but has leftover levels from a prior run,
      # clear them so height sums and display don't lie.
      Level.where(section_id: section.id).delete_all

      remaining_section_height = section.section_height.to_f

      # Helper lambdas (kept local so we don't change class surface area)
      level_00_rule = lambda do |a|
        a.dt == 1 ||
          (a.dt == 0 && (
            a.weight_g.to_f > 18_143.7 ||
            a.rssq.to_f > (a.palq.to_f / 2.0)
          ))
      end

      article_height = lambda do |a|
        if a.dt == 1
          (a.ul_height_gross || 0).to_f
        elsif a.dt == 0
          divisor = (a.mpq.to_i > 0) ? a.mpq.to_i : 1
          # Your rule: if dt=0 and mpq != 1 => (rssq/mpq) * cp_height
          # If mpq == 1, this is still (rssq/1) * cp_height.
          (a.rssq.to_f / divisor) * (a.cp_height || 0).to_f
        else
          (a.cp_height || 0).to_f
        end
      end

      tallest_dt_of_level = lambda do |arts|
        return 0 if arts.empty?
        tallest = arts.max_by { |a| article_height.call(a) }
        tallest&.dt.to_i
      end

      # Build levels from 00..19
      (0..19).each do |level_index|
        break if queue.empty?
        break if remaining_section_height <= 0

        level_num_str = format("%02d", level_index)

        # Select candidate set per your rules
        candidates =
          if level_index == 0
            queue.select { |a| level_00_rule.call(a) }
          else
            # "Every other dt=0 must go on other levels" (i.e., dt=0 not forced into level 00)
            queue.select { |a| a.dt == 0 && !level_00_rule.call(a) }
                 .sort_by { |a| a.weight_g.to_f } # lighter on lower levels
          end

        # If no candidates for this level:
        # - Level 00: just skip creating it.
        # - Other levels: if nothing left for non-00, we can stop.
        if candidates.empty?
          next if level_index == 0
          break
        end

        # Width/Depth constrained greedy fill for THIS level
        remaining_width = section.section_width.to_f
        planned_for_level = []

        candidates.each do |art|
          next unless art.article_length.to_f <= section.section_depth.to_f
          next unless art.article_width.to_f <= remaining_width

          planned_for_level << art
          remaining_width -= art.article_width.to_f
        end

        # Nothing fit => stop making further levels (width/depth constraints block progress)
        if planned_for_level.empty?
          next if level_index == 0
          break
        end

        # Compute level height
        tallest_height = planned_for_level.map { |a| article_height.call(a) }.max.to_f
        dominant_dt = tallest_dt_of_level.call(planned_for_level)
        clearance = (dominant_dt == 1) ? 254.0 : 127.0
        level_height = tallest_height + clearance

        # HARD CONSTRAINT: sum(level_heights) must not exceed section.section_height
        if level_height > remaining_section_height
          # Can't fit this level; stop planning more levels in this section.
          break
        end

        # Persist level
        if section.respond_to?(:levels)
          section.levels.create!(
            level_num: level_num_str,
            level_height: level_height
          )
        end

        # Persist article assignments (and your new_assq update when mpq == 1)
        planned_for_level.each do |art|
          if art.dt == 0 && art.mpq.to_i == 1
            art.update!(new_assq: art.rssq)
          end
          art.update!(section_id: section.id, planned: true)
          queue.delete(art)
          planned_count += 1
        end

        remaining_section_height -= level_height

        # After level 00, we continue; after other levels, loop continues until 19 or height full.
      end
    end

    unplanned_count = queue.count

    {
      success: true,
      planned_count: planned_count,
      unplanned_count: unplanned_count,
      message: "Greedy Planning Complete: Assigned #{planned_count} articles. #{unplanned_count} remain."
    }
  end

  # --- Mode-Specific Planning Logic ---

  def plan_non_opul
    res = base_section_planner(plan_strategy: :non_opul)
    res.merge(message: "Non-OPUL planning completed. Assigned #{res[:planned_count]} articles. #{res[:unplanned_count]} remain.")
  end

  def plan_opul
    res = base_section_planner(plan_strategy: :opul)
    res.merge(message: "OPUL planning completed. Assigned #{res[:planned_count]} articles. #{res[:unplanned_count]} remain.")
  end

  def plan_countertop
    res = base_section_planner(plan_strategy: :countertop)
    res.merge(message: "Countertop planning completed. Assigned #{res[:planned_count]} articles.")
  end

  def plan_voss
    base_section_planner(plan_strategy: :voss_assignment)
  end

  def plan_pallet
    base_section_planner(plan_strategy: :pallet_assignment)
  end

  # --- Core Article Filtering Logic ---

  def base_articles_scope
    scope = @aisle.pair.store.articles

    # 1. Apply optional Name Prefix filter
    if name_prefix
      scope = scope.where('artname_unicode ILIKE ?', "#{name_prefix}%")
    end

    # 2. Apply PA/HFB filter
    scope = apply_pa_hfb_filter(scope)

    # 3. Apply basic EXPSALE filters
    if low_expsale_only?
      scope = scope.where('expsale < 5')
    elsif high_expsale_only?
      scope = scope.where('expsale > 5')

      if high_expsale_require_dt1?
        scope = scope.where(dt: 1)
      end
    end

    # 4. Filter out articles already planned
    scope = scope.where(planned: [false, nil])

    # 5. Apply VOSS gates only if VOSS mode is selected.
    if planning_mode == 'voss_mode'
      scope = apply_voss_gates(scope)
    end

    return scope
  end

  # --- Private Helper Methods (Parameter Extraction and Filtering) ---

  def planning_mode
    @params[:mode]
  end

  def name_prefix
    @params[:name_prefix].presence
  end

  def low_expsale_only?
    @params[:low_expsale_only].present?
  end

  def high_expsale_only?
    @params[:high_expsale_only].present?
  end

  def high_expsale_require_dt1?
    @params[:high_expsale_require_dt1].present?
  end

  def apply_pa_hfb_filter(scope)
    filter_value = @params[:filter_value].presence
    return scope unless filter_value

    case @params[:filter_type]
    when 'PA'
      scope.where(pa: filter_value)
    when 'HFB'
      scope.where(hfb: filter_value)
    else
      scope
    end
  end

  def apply_voss_gates(scope)
    scope = scope.where(dt: 0) # VOSS requirement

    if @params[:voss_cp_height_max].present?
      scope = scope.where('cp_height <= ?', @params[:voss_cp_height_max])
    end
    if @params[:voss_cp_length_max].present?
      scope = scope.where('cp_length <= ?', @params[:voss_cp_length_max])
    end
    if @params[:voss_cp_width_max].present?
      scope = scope.where('cp_width <= ?', @params[:voss_cp_width_max])
    end
    if @params[:voss_rssq_max].present?
      scope = scope.where('rssq <= ?', @params[:voss_rssq_max])
    end
    if @params[:voss_expsale_max].present?
      scope = scope.where('expsale <= ?', @params[:voss_expsale_max])
    end
    if @params[:voss_weight_g_max].present?
      scope = scope.where('weight_g <= ?', @params[:voss_weight_g_max])
    end

    return scope
  end
end
