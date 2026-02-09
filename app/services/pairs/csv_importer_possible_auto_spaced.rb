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

      # ⭐ ONLY ADDITION — ensure LOC has valid bay segment
      rows = rows.select { |row| valid_bay?(row) }

      rows
        .group_by { |row| pair_key(row["LOC"]) }
        .each do |pair_num, pair_records|
          create_pair_with_aisles(pair_num, pair_records)
        end
    end

    private

    attr_reader :store

    # ------------------------
    # BAY HELPERS ⭐ ONLY NEW LOGIC
    # ------------------------

    def valid_bay?(row)
      bay_from_loc(row["LOC"]).present?
    end

    def bay_from_loc(loc)
      parse_loc(loc)[:section]
    end

    # ------------------------
    # PAIR + MULTI AISLES
    # ------------------------

    def create_pair_with_aisles(pair_num, pair_records)
      depth = calculate_pair_depth(pair_records)

      pair = store.pairs.create!(
        pair_nums: pair_num,
        pair_depth: depth,
        pair_height: PAIR_HEIGHT,
        pair_section_width: PAIR_SECTION_WIDTH,
        pair_sections: calculate_section_count(pair_records),
        pair_division: extract_pair_divisions(pair_records).join(","),
        skip_auto_aisles: true
      )

      pair_records
        .select { |r| r["DIVISION"].to_s.strip != "" }
        .group_by { |r| r["DIVISION"].strip }
        .each do |division, division_records|
          create_aisle_for_division(pair, division, division_records)
        end
    end

    # ------------------------
    # AISLE PER DIVISION
    # ------------------------

    def create_aisle_for_division(pair, division, records)
      section_count = calculate_section_count(records)

      aisle = pair.aisles.create!(
        aisle_num: "#{pair.pair_nums} #{division}",
        aisle_depth: pair.pair_depth,
        aisle_height: pair.pair_height,
        aisle_section_width: pair.pair_section_width,
        aisle_sections: section_count
      )

      (1..section_count).each do |section_num|
        aisle.sections.create!(
          section_num: section_num,
          section_depth: aisle.aisle_depth,
          section_height: aisle.aisle_height,
          section_width: aisle.aisle_section_width
        )
      end
    end

    # ------------------------
    # HELPERS
    # ------------------------

    def extract_pair_divisions(records)
      records.map { |r| r["DIVISION"]&.strip }.compact.uniq
    end

    def parse_loc(loc)
      pair, section, depth = loc.to_s.strip.split("-")
      { pair: pair, section: section, depth: depth }
    end

    def pair_key(loc)
      parse_loc(loc)[:pair]
    end

    # ------------------------
    # DERIVATIONS
    # ------------------------

    def calculate_section_count(records)
      face_rows =
        records.count do |row|
          parse_loc(row["LOC"])[:depth].to_s.strip == "00"
        end

      return 1 if face_rows.zero?

      (face_rows / 3.0).ceil
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

