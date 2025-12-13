require "application_system_test_case"

class AislesTest < ApplicationSystemTestCase
  setup do
    @aisle = aisles(:one)
  end

  test "visiting the index" do
    visit aisles_url
    assert_selector "h1", text: "Aisles"
  end

  test "should create aisle" do
    visit aisles_url
    click_on "New aisle"

    fill_in "Aisle depth", with: @aisle.aisle_depth
    fill_in "Aisle height", with: @aisle.aisle_height
    fill_in "Aisle num", with: @aisle.aisle_num
    fill_in "Aisle section width", with: @aisle.aisle_section_width
    fill_in "Aisle sections", with: @aisle.aisle_sections
    fill_in "Pair", with: @aisle.pair_id
    click_on "Create Aisle"

    assert_text "Aisle was successfully created"
    click_on "Back"
  end

  test "should update Aisle" do
    visit aisle_url(@aisle)
    click_on "Edit this aisle", match: :first

    fill_in "Aisle depth", with: @aisle.aisle_depth
    fill_in "Aisle height", with: @aisle.aisle_height
    fill_in "Aisle num", with: @aisle.aisle_num
    fill_in "Aisle section width", with: @aisle.aisle_section_width
    fill_in "Aisle sections", with: @aisle.aisle_sections
    fill_in "Pair", with: @aisle.pair_id
    click_on "Update Aisle"

    assert_text "Aisle was successfully updated"
    click_on "Back"
  end

  test "should destroy Aisle" do
    visit aisle_url(@aisle)
    click_on "Destroy this aisle", match: :first

    assert_text "Aisle was successfully destroyed"
  end
end
