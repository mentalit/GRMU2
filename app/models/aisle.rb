class Aisle < ApplicationRecord
  belongs_to :pair
  delegate :store, to: :pair

  has_many :sections, dependent: :destroy
  has_many :articles, through: :sections

  after_create :create_sections
  after_update_commit :sync_sections, if: :sync_sections?

  private

  def create_sections
    (1..aisle_sections.to_i).each do |sec|
      sections.create!(
        section_num: sec,
        section_depth: aisle_depth,
        section_height: aisle_height,
        section_width: aisle_section_width
      )
    end
  end

  def sync_sections
    sections.update_all(
      section_depth: aisle_depth,
      section_height: aisle_height,
      section_width: aisle_section_width,
      updated_at: Time.current
    )
  end

  def sync_sections?
    saved_change_to_aisle_depth? ||
      saved_change_to_aisle_height? ||
      saved_change_to_aisle_section_width?
  end
end
