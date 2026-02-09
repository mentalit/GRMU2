# frozen_string_literal: true

require "csv"

module Pairs
  class CsvImporter
    PAIR_HEIGHT = 2286
    DEFAULT_SECTION_WIDTH = 3000
    COMPARTMENT_WIDTH_UNIT = 1000

    def initialize(file:, store:)
      @file  = file
      @store = store
    end

    def call
      grouped_rows.each do |pair_num, pair_records|
        create_pair_with_aisles(pair_num, pair_records)
      end
    end

    private

    attr_reader :file, :store

    # --------------------------------------------------
    # CSV
    # --------------------------------------------------

    def rows
      @rows ||= CSV.read(
        file.path,
        headers: true,
        header_converters: ->(h) { h&.strip }
      )
    end

    def grouped_rows
      rows.group_by { |row| pair_key(row["LOC"]) }
    end

    # --------------------------------------------------
    # PAIR
    # --------------------------------------------------

    def create_pair_with_aisles(pair_num, pair_records)
      valid_pair_records = valid_face_records(pair_records)

      use_compartment_strategy =
        use_compartment_sections?(valid_pair_records)

      pair = store.pairs.create!(
        pair_nums: pair_num,
        pair_depth: derive_pair_depth(pair_records),
        pair_height: PAIR_HEIGHT,
        pair_section_width: DEFAULT_SECTION_WIDTH,
        pair_sections: calculate_section_count(valid_pair_records),
        pair_division: extract_pair_divisions(pair_records).join(","),
        skip_auto_aisles: true
      )

      pair_records
        .select { |r| r["DIVISION"].to_s.strip.present? }
        .group_by { |r| r["DIVISION"].strip }
        .each do |division, division_records|
          create_aisle(
            pair,
            division,
            division_records,
            use_compartment_strategy
          )
        end
    end

    # --------------------------------------------------
    # AISLES (PAIR LEVEL STRATEGY)
    # --------------------------------------------------

    def create_aisle(pair, division, records, use_compartment_strategy)
      valid_records = valid_face_records(records)

      if use_compartment_strategy
        create_compartment_aisle(pair, division, valid_records)
      else
        create_standard_aisle(pair, division, valid_records)
      end
    end

    # -----------------------------
    # COMPARTMENT MODE
    # -----------------------------

    def create_compartment_aisle(pair, division, valid_records)
      groups = group_by_compartment(valid_records)

      aisle = build_aisle(
        pair: pair,
        division: division,
        section_count: groups.size,
        section_width: nil
      )

      groups.each_with_index do |(_compartment, locs), index|
        width = locs.count * COMPARTMENT_WIDTH_UNIT

        create_section(
          aisle: aisle,
          section_num: index + 1,
          width: width
        )
      end
    end

    # -----------------------------
    # LEGACY MODE
    # -----------------------------

    def create_standard_aisle(pair, division, valid_records)
      section_count = calculate_section_count(valid_records)

      aisle = build_aisle(
        pair: pair,
        division: division,
        section_count: section_count,
        section_width: pair.pair_section_width
      )

      (1..section_count).each do |section_num|
        create_section(
          aisle: aisle,
          section_num: section_num,
          width: aisle.aisle_section_width
        )
      end
    end

    # --------------------------------------------------
    # BUILDERS
    # --------------------------------------------------

    def build_aisle(pair:, division:, section_count:, section_width:)
      pair.aisles.create!(
        aisle_num: "#{pair.pair_nums} #{division}",
        aisle_depth: pair.pair_depth,
        aisle_height: pair.pair_height,
        aisle_section_width: section_width,
        aisle_sections: section_count
      )
    end

    def create_section(aisle:, section_num:, width:)
      aisle.sections.create!(
        section_num: section_num,
        section_depth: aisle.aisle_depth,
        section_height: aisle.aisle_height,
        section_width: width
      )
    end

    # --------------------------------------------------
    # FILTERING
    # --------------------------------------------------

    def valid_face_records(records)
      records.select { |r| valid_face_loc?(r) }
    end

    def valid_face_loc?(row)
      depth = parse_loc(row["LOC"])[:depth].to_s.strip
      compartment = row["COMPARTMENT"].to_s.strip

      depth == "00" && compartment.match?(/\A[A-Za-z]/)
    end

    # --------------------------------------------------
    # SAFE COMPARTMENTS
    # --------------------------------------------------

    def compartment_letter(row)
      compartment = row["COMPARTMENT"].to_s.strip
      return nil if compartment.empty?

      compartment.split("-").first.to_s.strip
    end

    def group_by_compartment(records)
      records
        .map { |r| [compartment_letter(r), r] }
        .reject { |letter, _| letter.nil? || letter.empty? }
        .group_by(&:first)
        .transform_values { |pairs| pairs.map(&:last) }
    end

    def use_compartment_sections?(valid_records)
      group_by_compartment(valid_records).keys.size > 1
    end

    # --------------------------------------------------
    # MAXLENGTH DEPTH OVERRIDE
    # --------------------------------------------------

    def derive_pair_depth(pair_records)
      maxlength = max_compartment_maxlength(pair_records)

      return maxlength * 10 if maxlength && maxlength > 1

      calculate_pair_depth(pair_records)
    end

    def max_compartment_maxlength(pair_records)
      pair_records
        .map { |r| [compartment_letter(r), r] }
        .reject { |letter, _| letter.nil? || letter.empty? }
        .group_by(&:first)
        .values
        .map do |pairs|
          records = pairs.map(&:last)
          max_maxlength_in_records(records)
        end
        .compact
        .max
    end

    def max_maxlength_in_records(records)
      records
        .map { |r| r["MAXLENGTH"] || r["maxlength"] }
        .compact
        .map(&:to_i)
        .max
    end

    # --------------------------------------------------
    # HELPERS
    # --------------------------------------------------

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

    # --------------------------------------------------
    # DERIVATIONS
    # --------------------------------------------------

    def calculate_section_count(valid_records)
      face_rows = valid_records.count
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

