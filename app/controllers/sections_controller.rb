class SectionsController < ApplicationController
  before_action :set_section, only: %i[ show edit update destroy ]
  before_action :get_aisle, only: %i[ new create index plan]

  # GET /sections or /sections.json
  def index
    @sections = @aisle.sections
  end

  # GET /sections/1 or /sections/1.json
  def show
  end

  # GET /sections/new
  def new
    @section = @aisle.sections.build
  end

  # GET /sections/1/edit
  def edit
  end

  def plan
    # The @aisle object is already available via the before_action :get_aisle
    # which is called because :plan is listed in the 'only' array.

    # 1. Instantiate the service with the required objects and parameters.
    # The BinPlannerService must be created in app/services/bin_planner_service.rb
    service = BinPlannerService.new(aisle: @aisle, params: params)
    
    # 2. Execute the service.
    result = service.call

    # 3. Handle the result.
    if result[:success]
      # A successful plan should ideally redirect to a page showing the new layout
      # (e.g., the index page for sections in that aisle).
      redirect_to aisle_sections_path(@aisle), 
                  notice: "Bin planning completed successfully in #{params[:mode].humanize} mode."
    else
      # If the service failed (e.g., validation error, logic error)
      flash.alert = "Bin planning failed: #{result[:message]}"
      # Redirect back to the form's original page to show the error
      redirect_to aisle_sections_path(@aisle), status: :unprocessable_entity
    end
  rescue NameError => e
    # Catching a NameError is a good idea initially if the service or its dependencies 
    # haven't been fully defined yet.
    redirect_to aisle_sections_path(@aisle), 
                alert: "Error: BinPlannerService not ready. #{e.message}"
  end

  def unassign
    # Find the article by the ID passed in the route
    article = Article.find(params[:id])
    
    # Update the article to be unplanned and clear its section assignment
    article.update!(section_id: nil, planned: false)
    
    # Redirect back to the sections index page for the current aisle
    redirect_to aisle_sections_path(article.section.aisle), notice: "Article #{article.artno} unassigned successfully."
  rescue ActiveRecord::RecordNotFound
    redirect_back fallback_location: root_path, alert: "Article not found."
  rescue => e
    redirect_back fallback_location: root_path, alert: "Failed to unassign article: #{e.message}"
  end

  def bulk_unassign
  # The ID in params[:id] is the Aisle ID
  aisle = Aisle.find(params[:id])

  section_ids = aisle.sections.pluck(:id)

  # 1. Unassign ALL articles in this aisle
  Article.where(section_id: section_ids)
         .update_all(section_id: nil, planned: false)

  # 2. HARD DELETE ALL levels in this aisle
  # (must NOT use section.levels because of NOT NULL constraint)
  Level.where(section_id: section_ids).delete_all

  redirect_to aisle_sections_path(aisle),
    notice: "All articles unassigned and ALL levels destroyed for Aisle #{aisle.aisle_num}."
end

  # ACTION ADDED: POST /aisles/:aisle_id/sections/plan (Handles the planning process)
  
  # POST /sections or /sections.json
  def create
    @section = @aisle.sections.build(section_params)

    respond_to do |format|
      if @section.save
        format.html { redirect_to @section, notice: "Section was successfully created." }
        format.json { render :show, status: :created, location: @section }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @section.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /sections/1 or /sections/1.json
  def update
    respond_to do |format|
      if @section.update(section_params)
        format.html { redirect_to @section, notice: "Section was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @section }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @section.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /sections/1 or /sections/1.json
  def destroy
    @section.destroy!

    respond_to do |format|
      format.html { redirect_to aisle_sections_path(@section.aisle), notice: "Section was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_section
      @section = Section.find(params[:id])
    end

    def get_aisle
      @aisle = Aisle.find(params[:aisle_id])
    end

    # Only allow a list of trusted parameters through.
    def section_params
      params.require(:section).permit(:section_num, :section_depth, :section_height, :section_width, :aisle_id)
    end
end
