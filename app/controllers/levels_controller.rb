class LevelsController < ApplicationController
  before_action :set_level, only: %i[ show edit update destroy ]
  before_action :get_section, only: %i[ new create index]

  # GET /levels or /levels.json
  def index
    @levels = @section.levels
  end

  # GET /levels/1 or /levels/1.json
  def show
  end

  # GET /levels/new
  def new
    @level = @section.levels.build
  end

  # GET /levels/1/edit
  def edit
  end

  # POST /levels or /levels.json
  def create
    @level = @section.levels.build(level_params)

    respond_to do |format|
      if @level.save
        format.html { redirect_to @level, notice: "Level was successfully created." }
        format.json { render :show, status: :created, location: @level }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @level.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /levels/1 or /levels/1.json
  def update
    respond_to do |format|
      if @level.update(level_params)
        format.html { redirect_to @level, notice: "Level was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @level }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @level.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /levels/1 or /levels/1.json
  def destroy
    @level.destroy!

    respond_to do |format|
      format.html { redirect_to section_levels_path(@level.section), notice: "Level was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_level
      @level = Level.find(params[:id])
    end

    def get_section
      @section = Section.find(params[:section_id])
    end

    # Only allow a list of trusted parameters through.
    def level_params
      params.require(:level).permit(:level_height, :section_id)
    end
end


    