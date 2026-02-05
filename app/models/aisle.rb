class Aisle < ApplicationRecord
  attr_accessor :skip_section_creation
  belongs_to :pair
  delegate :store, to: :pair

  has_many :sections, dependent: :destroy



  # ⚠️ Structural relationship (articles exist in sections)
  has_many :articles, through: :sections

  # ✅ Planning-aware relationships (THIS is what you want to count)
  has_many :placements, through: :sections
  has_many :planned_articles,
           -> { distinct },
           through: :placements,
           source: :article

  # after_create :create_sections, unless: :skip_section_creation
  after_update_commit :sync_sections, if: :sync_sections?

  # ------------------------
  # Public API
  # ------------------------

  def planned_articles_count
    planned_articles.count
  end

  def add_sections(count)
    Rails.logger.info "ADDING #{count} SECTIONS TO AISLE #{id}"

    next_section_num = sections.maximum(:section_num).to_i + 1

    count.times do |i|
      sections.create!(
        section_num: next_section_num + i,
        section_depth: aisle_depth,
        section_height: aisle_height,
        section_width: aisle_section_width
      )
    end
  end

   


  # def articles_in_aisle(hfb_or_pa)
  #   @article_hfb_pa = []

  #   @articles.each do |art|
  #     @article_hfb_pa << art.hfb_or_pa
  #   end

  #   @article_hfb_pa.uniq
  # end

  # ------------------------
  # Callbacks
  # ------------------------
  private

 def create_sections
  return if sections.exists?          # 🔒 idempotent
  return if aisle_sections.to_i <= 0

  (1..aisle_sections).each do |sec|
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
