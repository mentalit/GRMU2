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
  
  # This method performs all setup steps common to every planning mode.
  def base_section_planner(plan_strategy:)
    # 1. Get the filtered articles and convert to array to attach temporary attributes
    articles = base_articles_scope.to_a 
    
    # 2. Initialize the sorting arrays
    @deep_articles = []
    @shallow_articles = []
    
    # Track skipped articles for logging
    skipped_count = 0 

    # 3. Iterate, calculate dimensions, store them, and sort the articles
    articles.each do |art|
      # Logic to determine which dimensions (UL or CP) to use
      if art.dt == 1 || (art.dt == 0 && (art.rssq > art.palq))
        # Use UL (Unit Load) dimensions
        calculated_width = art.ul_width_gross
        calculated_length = art.ul_length_gross
        calculated_height = art.ul_height_gross
      else
        # Use CP (Case Pack) dimensions
        calculated_width = art.cp_width
        calculated_length = art.cp_length
        calculated_height = art.cp_height
      end

      # NEW GUARD CLAUSE: Skip article if the required length dimension is missing or invalid.
      unless calculated_length.is_a?(Numeric)
        Rails.logger.warn "PLANNER: Skipping article ID #{art.id} (Art No: #{art.artno}) due to missing or non-numeric length dimension."
        skipped_count += 1
        next 
      end
      
      # Attach the calculated values to the article object for later use.
      art.define_singleton_method(:article_width) { calculated_width }
      art.define_singleton_method(:article_length) { calculated_length }
      art.define_singleton_method(:article_height) { calculated_height }

      # 4. SORTING LOGIC: ONLY USES LENGTH (Now safe because article_length is guaranteed to be numeric)
      if art.article_length > 1524
        @deep_articles << art
      else
        @shallow_articles << art
      end
    end
    
    # 5. Common Preparation: KEEP EXISTING PLANS (NO CLEANUP)
    # The cleanup line is intentionally omitted to preserve existing assignments.

    Rails.logger.info "PLANNER: Base setup complete. Strategy: #{plan_strategy}. Deep Arts: #{@deep_articles.count}, Shallow Arts: #{@shallow_articles.count}. Skipped: #{skipped_count}."
    
    # 6. Execute the mode-specific planning logic
    planning_result = send(plan_strategy)
    
    return planning_result
  end

  # --- Mode-Specific Planning Logic ---

  def plan_non_opul
    base_section_planner(plan_strategy: :non_opul_assignment)
  end
  
  # The actual assignment logic for Non-OPUL mode
  def non_opul_assignment
    # Combine articles, prioritizing shallow ones for assignment first (common strategy)
    articles_to_assign = @shallow_articles + @deep_articles 
    
    # Filter sections to only use those with NO assigned article.
    available_sections = @aisle.sections
                             .left_joins(:articles)
                             .where(articles: { id: nil }) 
                             .order(:section_num)
    
    planned_count = 0
    
    # Assignment Loop: Iterate through AVAILABLE sections and assign an unplanned article to each.
    available_sections.each do |section|
      
      # Find the index of the first available article that fits the section's depth
      article_to_assign_index = articles_to_assign.find_index do |art|
        # CORE PLANNING RULE: Article length must be less than the section depth
        art.article_length < section.section_depth
      end

      if article_to_assign_index.present?
        art = articles_to_assign.delete_at(article_to_assign_index)
        
        # DATABASE UPDATE: Assign the article to the section and mark as planned
        art.update!(section_id: section.id, planned: true)
        planned_count += 1
      end
      
      # Stop loop if we run out of articles to assign
      break if articles_to_assign.empty?
    end

    unplanned_count = articles_to_assign.count # Remaining articles that couldn't be planned
    
    # Final Result
    { 
      success: true, 
      message: "Non-OPUL planning completed. Assigned #{planned_count} articles to available sections. #{unplanned_count} articles remain.", 
      planned_count: planned_count, 
      unplanned_count: unplanned_count
    }
  end

  # Now calls the base planner and executes opul_assignment
  def plan_opul
    base_section_planner(plan_strategy: :opul_assignment)
  end
  
  # The actual assignment logic for OPUL mode (currently identical to non-opul, ready for customization)
  def opul_assignment
    articles_to_assign = @shallow_articles + @deep_articles 
    
    # Filter sections to only use those with NO assigned article.
    available_sections = @aisle.sections
                             .left_joins(:articles)
                             .where(articles: { id: nil }) 
                             .order(:section_num)
    
    planned_count = 0
    
    # Assignment Loop: Iterate through AVAILABLE sections and assign an unplanned article to each.
    available_sections.each do |section|
      
      # Find the index of the first available article that fits the section's depth
      article_to_assign_index = articles_to_assign.find_index do |art|
        # CORE PLANNING RULE: Article length must be less than the section depth
        art.article_length < section.section_depth
      end

      if article_to_assign_index.present?
        art = articles_to_assign.delete_at(article_to_assign_index)
        
        # DATABASE UPDATE: Assign the article to the section and mark as planned
        art.update!(section_id: section.id, planned: true)
        planned_count += 1
      end
      
      # Stop loop if we run out of articles to assign
      break if articles_to_assign.empty?
    end

    unplanned_count = articles_to_assign.count
    
    # Final Result
    { 
      success: true, 
      message: "OPUL planning completed. Assigned #{planned_count} articles to available sections. #{unplanned_count} articles remain.", 
      planned_count: planned_count, 
      unplanned_count: unplanned_count
    }
  end


  def plan_countertop
    base_section_planner(plan_strategy: :countertop_assignment)
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