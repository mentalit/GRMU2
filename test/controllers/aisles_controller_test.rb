require "test_helper"

class AislesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @aisle = aisles(:one)
  end

  test "should get index" do
    get aisles_url
    assert_response :success
  end

  test "should get new" do
    get new_aisle_url
    assert_response :success
  end

  test "should create aisle" do
    assert_difference("Aisle.count") do
      post aisles_url, params: { aisle: { aisle_depth: @aisle.aisle_depth, aisle_height: @aisle.aisle_height, aisle_num: @aisle.aisle_num, aisle_section_width: @aisle.aisle_section_width, aisle_sections: @aisle.aisle_sections, pair_id: @aisle.pair_id } }
    end

    assert_redirected_to aisle_url(Aisle.last)
  end

  test "should show aisle" do
    get aisle_url(@aisle)
    assert_response :success
  end

  test "should get edit" do
    get edit_aisle_url(@aisle)
    assert_response :success
  end

  test "should update aisle" do
    patch aisle_url(@aisle), params: { aisle: { aisle_depth: @aisle.aisle_depth, aisle_height: @aisle.aisle_height, aisle_num: @aisle.aisle_num, aisle_section_width: @aisle.aisle_section_width, aisle_sections: @aisle.aisle_sections, pair_id: @aisle.pair_id } }
    assert_redirected_to aisle_url(@aisle)
  end

  test "should destroy aisle" do
    assert_difference("Aisle.count", -1) do
      delete aisle_url(@aisle)
    end

    assert_redirected_to aisles_url
  end
end
