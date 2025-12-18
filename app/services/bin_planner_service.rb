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
  # This method performs all setup steps common to every planning mode.
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
    # We use a mutable copy so we can pluck items out of it
    queue = @shallow_articles + @deep_articles
    
    # 4. Get available sections
    available_sections = @aisle.sections
                               .left_joins(:articles)
                               .group('sections.id')
                               .having('count(articles.id) = 0')
                               .order(:section_num)
    
    planned_count = 0

   # app/services/bin_planner_service.rb

# ... inside base_section_planner(plan_strategy:) ...

    # 5. GREEDY BIN PACKING LOOP
    available_sections.each do |section|
      current_remaining_width = section.section_width
      max_article_height = 0
      dominant_dt = 0 
      
      i = 0
      while i < queue.length
        art = queue[i]
        
        if art.article_length <= section.section_depth && art.article_width <= current_remaining_width
          # 1. Assign in Database
          art.update!(section_id: section.id, planned: true)
          
          # --- INTEGRATED HEIGHT LOGIC ---
          if art.dt == 1
            # Standard DT=1 logic
            art_height = art.ul_height_gross || 0
            dominant_dt = 1
          elsif art.dt == 0
            # Apply your specific rssq/mpq rules for dt=0
            if art.mpq == 1
              art.update!(new_assq: art.rssq) # Update new_assq as requested
              art_height = (art.rssq || 0) * (art.cp_height || 0)
            else
              # Handles art.mpq != 1 (and safety check for nil/zero)
              divisor = (art.mpq.to_i > 0) ? art.mpq : 1
              art_height = ((art.rssq || 0).to_f / divisor) * (art.cp_height || 0)
            end
          else
            art_height = art.cp_height || 0
          end

          # Track the tallest required height in this section
          max_article_height = [max_article_height, art_height].max
          
          # --- END INTEGRATED HEIGHT LOGIC ---

          current_remaining_width -= art.article_width
          planned_count += 1
          queue.delete_at(i)
        else
          i += 1
        end
      end

      # --- DYNAMIC LEVEL HEIGHT CALCULATION ---
      if max_article_height > 0
        # Clearance based on if any DT=1 items were present
        clearance = (dominant_dt == 1) ? 254 : 127
        new_total_height = max_article_height + clearance
        
        # Create or update the Level record associated with the section
        level = section.levels.first_or_initialize
        level.update!(level_height: new_total_height)
      end

      break if queue.empty?
   
      

    unplanned_count = queue.count
    
    # Execute strategy (if any special logic is still needed) or return results
    { 
      success: true, 
      planned_count: planned_count, 
      unplanned_count: unplanned_count,
      message: "Greedy Planning Complete: Assigned #{planned_count} articles. #{unplanned_count} remain."
    }
  end

    unplanned_count = queue.count
    
    # Execute strategy (if any special logic is still needed) or return results
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