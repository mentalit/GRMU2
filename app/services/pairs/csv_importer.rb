# frozen_string_literal: true

require "csv"

module Pairs
  class CsvImporter
    PAIR_HEIGHT = 2286
    PAIR_SECTION_WIDTH = 3000

    def initialize(file:, store:)
      @file  = file
      @store = store
    end

    def call
      rows = CSV.read(
        @file.path,
        headers: true,
        header_converters: ->(h) { h&.strip }
      )

      rows
        .group_by { |row| pair_key(row["LOC"]) }
        .each do |pair_num, records|
          create_pair_with_aisle_and_sections(pair_num, records)
        end
    end

    private

    attr_reader :store

    # ------------------------
    # PAIR + AISLE + SECTIONS
    # ------------------------

    def create_pair_with_aisle_and_sections(pair_num, records)
      depth        = calculate_pair_depth(records)
      section_nums = extract_section_numbers(records)

      pair = store.pairs.create!(
        pair_nums: pair_num,
        pair_depth: depth,
        pair_height: PAIR_HEIGHT,
        pair_section_width: PAIR_SECTION_WIDTH,
        pair_sections: section_nums.size,
        skip_auto_aisles: true
      )

      aisle = pair.aisles.create!(
        aisle_num: pair.pair_nums,
        aisle_depth: pair.pair_depth,              # 🔒 invariant
        aisle_height: pair.pair_height,
        aisle_section_width: pair.pair_section_width,
        aisle_sections: section_nums.size
      )

      # 🔥 SECTIONS ARE CREATED HERE — NO EXCEPTIONS
      section_nums.each_with_index do |_sec, index|
        aisle.sections.create!(
          section_num: index + 1,
          section_depth: aisle.aisle_depth,         # ALWAYS pair_depth
          section_height: aisle.aisle_height,
          section_width: aisle.aisle_section_width
        )
      end
    end

    # ------------------------
    # LOC PARSING
    # ------------------------

    def parse_loc(loc)
      pair, section, depth = loc.to_s.split("-")
      { pair: pair, section: section, depth: depth }
    end

    def pair_key(loc)
      parse_loc(loc)[:pair]
    end

    # ------------------------
    # DERIVATIONS
    # ------------------------

    def extract_section_numbers(records)
      sections =
        records
          .map { |row| parse_loc(row["LOC"])[:section] }
          .uniq
          .sort

      raise "NO SECTIONS FOUND IN CSV" if sections.empty?

      sections
    end

    def calculate_pair_depth(records)
      depth =
        records
          .map { |row| parse_loc(row["LOC"])[:depth] }
          .uniq
          .count

      raise "INVALID DEPTH DERIVED FROM CSV" if depth.zero?

      depth
    end
  end
end
