class AislesController < ApplicationController
  before_action :set_aisle, only: %i[ show edit update destroy ]
  before_action :get_pair, only: %i[new create index]

  # GET /aisles or /aisles.json
  def index
    @aisles = @pair.aisles
  end

  # GET /aisles/1 or /aisles/1.json
  def show
  end

  # GET /aisles/new
  def new
    @aisle = @pair.aisles.build
  end

  # GET /aisles/1/edit
  def edit
  end

  # POST /aisles or /aisles.json
  def create
    @aisle = @pair.aisles.build(aisle_params)

    respond_to do |format|
      if @aisle.save
        format.html { redirect_to @aisle, notice: "Aisle was successfully created." }
        format.json { render :show, status: :created, location: @aisle }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @aisle.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /aisles/1 or /aisles/1.json
  def update
    respond_to do |format|
      if @aisle.update(aisle_params)
        format.html { redirect_to @aisle, notice: "Aisle was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @aisle }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @aisle.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /aisles/1 or /aisles/1.json
  def destroy
    @aisle.destroy!

    respond_to do |format|
      format.html { redirect_to aisles_path, notice: "Aisle was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_aisle
      @aisle = Aisle.find(params[:id])
    end

    def get_pair
      @pair = Pair.find(params[:pair_id])
    end

    # Only allow a list of trusted parameters through.
    def aisle_params
      params.require(:aisle).permit(:aisle_num, :aisle_height, :aisle_depth, :aisle_section_width, :aisle_sections, :pair_id)
    end
end
