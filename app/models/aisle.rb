class Aisle < ApplicationRecord
  belongs_to :pair
  has_many :sections


  after_create :create_sections

  private

  def create_sections
    section_range = (1..aisle_sections.to_i).to_a

    section_range.each do |sec |
      sections.create!(
        section_num: sec,
        section_depth: aisle_depth,
        section_height: aisle_height ,
        section_width: aisle_section_width 
        )
      end
  end


end


