class Pair < ApplicationRecord
  belongs_to :store
  has_many :aisles, dependent: :destroy

  attr_accessor :skip_auto_aisles

  after_create :create_aisles, unless: :skip_auto_aisles

  private

  def create_aisles
    aisle_numbers.each do |num|
      aisles.create!(
        aisle_num: num,
        aisle_depth: aisle_numbers.count == 1 ? pair_depth : pair_depth / 2,
        aisle_height: pair_height,
        aisle_section_width: pair_section_width,
        aisle_sections: pair_sections
      )
    end
  end

  def aisle_numbers
    pair_nums.split(",").map(&:strip)
  end
end

