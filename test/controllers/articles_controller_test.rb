require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @article = articles(:one)
  end

  test "should get index" do
    get articles_url
    assert_response :success
  end

  test "should get new" do
    get new_article_url
    assert_response :success
  end

  test "should create article" do
    assert_difference("Article.count") do
      post articles_url, params: { article: { artname_unicode: @article.artname_unicode, artno: @article.artno, baseonhand: @article.baseonhand, cp_diameter: @article.cp_diameter, cp_height: @article.cp_height, cp_length: @article.cp_length, cp_weight_gross: @article.cp_weight_gross, cp_width: @article.cp_width, dt: @article.dt, eds: @article.eds, expsale: @article.expsale, hfb: @article.hfb, mpq: @article.mpq, new_assq: @article.new_assq, new_loc: @article.new_loc, pa: @article.pa, palq: @article.palq, rssq: @article.rssq, sal_sol_indic: @article.sal_sol_indic, salesmethod: @article.salesmethod, slid_h: @article.slid_h, split_rssq: @article.split_rssq, ssd: @article.ssd, store_id: @article.store_id, ul_diamter: @article.ul_diamter, ul_height_gross: @article.ul_height_gross, ul_length_gross: @article.ul_length_gross, ul_width_gross: @article.ul_width_gross, weight_g: @article.weight_g } }
    end

    assert_redirected_to article_url(Article.last)
  end

  test "should show article" do
    get article_url(@article)
    assert_response :success
  end

  test "should get edit" do
    get edit_article_url(@article)
    assert_response :success
  end

  test "should update article" do
    patch article_url(@article), params: { article: { artname_unicode: @article.artname_unicode, artno: @article.artno, baseonhand: @article.baseonhand, cp_diameter: @article.cp_diameter, cp_height: @article.cp_height, cp_length: @article.cp_length, cp_weight_gross: @article.cp_weight_gross, cp_width: @article.cp_width, dt: @article.dt, eds: @article.eds, expsale: @article.expsale, hfb: @article.hfb, mpq: @article.mpq, new_assq: @article.new_assq, new_loc: @article.new_loc, pa: @article.pa, palq: @article.palq, rssq: @article.rssq, sal_sol_indic: @article.sal_sol_indic, salesmethod: @article.salesmethod, slid_h: @article.slid_h, split_rssq: @article.split_rssq, ssd: @article.ssd, store_id: @article.store_id, ul_diamter: @article.ul_diamter, ul_height_gross: @article.ul_height_gross, ul_length_gross: @article.ul_length_gross, ul_width_gross: @article.ul_width_gross, weight_g: @article.weight_g } }
    assert_redirected_to article_url(@article)
  end

  test "should destroy article" do
    assert_difference("Article.count", -1) do
      delete article_url(@article)
    end

    assert_redirected_to articles_url
  end
end
