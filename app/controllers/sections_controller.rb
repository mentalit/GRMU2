class SectionsController < ApplicationController
  before_action :set_section, only: %i[ show edit update destroy ]
  before_action :get_aisle, only: %i[ new create index]

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

  # ACTION ADDED: POST /aisles/:aisle_id/sections/plan (Handles the planning process)
  def plan
    # @aisle is available from the get_aisle before_action
    
    # Call the service object
    # params.permit!.to_h safely passes all form data as a hash to the service.
    result = BinPlannerService.call(
      aisle: @aisle, 
      mode: params[:mode], 
      params: params.permit!.to_h
    )

    respond_to do |format|
      if result[:status] == :success
        format.html { redirect_to aisle_path(@aisle), notice: result[:message] }
        format.json { render json: { message: result[:message] }, status: :ok }
      else
        format.html { redirect_to aisle_path(@aisle), alert: "Planning failed: #{result[:message]}" }
        format.json { render json: { error: result[:message] }, status: :unprocessable_entity }
      end
    end
  end

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
