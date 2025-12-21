class ArticlesController < ApplicationController
  before_action :set_article, only: %i[ show edit update destroy ]
  before_action :get_store,  only: %i[ new create index new_import import planned_articles]


  # GET /articles or /articles.json
  def index
    @articles = @store.articles
  end

  # GET /articles/1 or /articles/1.json
  def show
  end

  # GET /articles/new
  def new
     @article = @store.articles.build
  end

  def new_import
  end
 
  def import
    Articles::CsvImporter.import(
      params[:csv_file_1],
      params[:csv_file_2],
      store: @store
    )

    redirect_to store_articles_path(@store),
                notice: "Articles imported successfully"
  end
 
 def planned_articles
  @articles = @store.articles
  @planned_articles = Article.where(planned: true)

 end

  # GET /articles/1/edit
  def edit
  end

  # POST /articles or /articles.json
  def create
    @article = @store.articles.build(article_params)

    respond_to do |format|
      if @article.save
        format.html { redirect_to @article, notice: "Article was successfully created." }
        format.json { render :show, status: :created, location: @article }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @article.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /articles/1 or /articles/1.json
  def update
    respond_to do |format|
      if @article.update(article_params)
        format.html { redirect_to @article, notice: "Article was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @article }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @article.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /articles/1 or /articles/1.json
  def destroy
    @article.destroy!

    respond_to do |format|
      format.html { redirect_to articles_path, notice: "Article was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private

    # Use callbacks to share common setup or constraints between actions.
    def set_article
      @article = Article.find(params[:id])
    end

    def get_store
      @store = Store.find(params[:store_id])
    end

    # Only allow a list of trusted parameters through.
    def article_params
      params.require(:article).permit(:artno, :artname_unicode, :baseonhand, :weight_g, :slid_h, :ssd, :eds, :hfb, :expsale, :pa, :salesmethod, :rssq, :sal_sol_indic, :mpq, :palq, :dt, :cp_height, :cp_length, :cp_width, :cp_diameter, :cp_weight_gross, :ul_height_gross, :ul_length_gross, :ul_width_gross, :ul_diamter, :new_assq, :new_loc, :split_rssq, :store_id)
    end
end
