require "application_system_test_case"

class ArticlesTest < ApplicationSystemTestCase
  setup do
    @article = articles(:one)
  end

  test "visiting the index" do
    visit articles_url
    assert_selector "h1", text: "Articles"
  end

  test "should create article" do
    visit articles_url
    click_on "New article"

    fill_in "Artname unicode", with: @article.artname_unicode
    fill_in "Artno", with: @article.artno
    fill_in "Baseonhand", with: @article.baseonhand
    fill_in "Cp diameter", with: @article.cp_diameter
    fill_in "Cp height", with: @article.cp_height
    fill_in "Cp length", with: @article.cp_length
    fill_in "Cp weight gross", with: @article.cp_weight_gross
    fill_in "Cp width", with: @article.cp_width
    fill_in "Dt", with: @article.dt
    fill_in "Eds", with: @article.eds
    fill_in "Expsale", with: @article.expsale
    fill_in "Hfb", with: @article.hfb
    fill_in "Mpq", with: @article.mpq
    fill_in "New assq", with: @article.new_assq
    fill_in "New loc", with: @article.new_loc
    fill_in "Pa", with: @article.pa
    fill_in "Palq", with: @article.palq
    fill_in "Rssq", with: @article.rssq
    fill_in "Sal sol indic", with: @article.sal_sol_indic
    fill_in "Salesmethod", with: @article.salesmethod
    fill_in "Slid h", with: @article.slid_h
    fill_in "Split rssq", with: @article.split_rssq
    fill_in "Ssd", with: @article.ssd
    fill_in "Store", with: @article.store_id
    fill_in "Ul diamter", with: @article.ul_diamter
    fill_in "Ul height gross", with: @article.ul_height_gross
    fill_in "Ul length gross", with: @article.ul_length_gross
    fill_in "Ul width gross", with: @article.ul_width_gross
    fill_in "Weight g", with: @article.weight_g
    click_on "Create Article"

    assert_text "Article was successfully created"
    click_on "Back"
  end

  test "should update Article" do
    visit article_url(@article)
    click_on "Edit this article", match: :first

    fill_in "Artname unicode", with: @article.artname_unicode
    fill_in "Artno", with: @article.artno
    fill_in "Baseonhand", with: @article.baseonhand
    fill_in "Cp diameter", with: @article.cp_diameter
    fill_in "Cp height", with: @article.cp_height
    fill_in "Cp length", with: @article.cp_length
    fill_in "Cp weight gross", with: @article.cp_weight_gross
    fill_in "Cp width", with: @article.cp_width
    fill_in "Dt", with: @article.dt
    fill_in "Eds", with: @article.eds
    fill_in "Expsale", with: @article.expsale
    fill_in "Hfb", with: @article.hfb
    fill_in "Mpq", with: @article.mpq
    fill_in "New assq", with: @article.new_assq
    fill_in "New loc", with: @article.new_loc
    fill_in "Pa", with: @article.pa
    fill_in "Palq", with: @article.palq
    fill_in "Rssq", with: @article.rssq
    fill_in "Sal sol indic", with: @article.sal_sol_indic
    fill_in "Salesmethod", with: @article.salesmethod
    fill_in "Slid h", with: @article.slid_h
    fill_in "Split rssq", with: @article.split_rssq
    fill_in "Ssd", with: @article.ssd
    fill_in "Store", with: @article.store_id
    fill_in "Ul diamter", with: @article.ul_diamter
    fill_in "Ul height gross", with: @article.ul_height_gross
    fill_in "Ul length gross", with: @article.ul_length_gross
    fill_in "Ul width gross", with: @article.ul_width_gross
    fill_in "Weight g", with: @article.weight_g
    click_on "Update Article"

    assert_text "Article was successfully updated"
    click_on "Back"
  end

  test "should destroy Article" do
    visit article_url(@article)
    click_on "Destroy this article", match: :first

    assert_text "Article was successfully destroyed"
  end
end
