require "csv"

module Pairs
  class CsvImporter

    PAIR_HEIGHT = 2286
    PAIR_SECTION_WIDTH = 3000

    def initialize(file:, store:)
      @file = file
      @store = store
    end

    def call
      rows = CSV.read(@file.path, headers: true)

      grouped = rows.group_by { |r| pair_key(r["SGFLOCATION"]) }

      grouped.each do |pair_num, records|
        create_pair(pair_num, records)
      end
    end

    private

    attr_reader :store

    # ------------------------
    # PAIR CREATION
    # ------------------------

    def create_pair(pair_num, records)
      depth = records.first["DEPTH"].to_i

      sections = calculate_sections(records)

      pair = store.pairs.create!(
        pair_nums: pair_num,
        pair_depth: depth,
        pair_height: PAIR_HEIGHT,
        pair_section_width: PAIR_SECTION_WIDTH,
        pair_sections: sections,
        skip_auto_aisles: true
      )

      create_single_aisle(pair)
    end

    # ------------------------
    # SINGLE AISLE FOR CSV
    # ------------------------

    def create_single_aisle(pair)
      pair.aisles.create!(
        aisle_num: pair.pair_nums,
        aisle_depth: pair.pair_depth,
        aisle_height: pair.pair_height,
        aisle_section_width: pair.pair_section_width,
        aisle_sections: pair.pair_sections
      )
    end

    # ------------------------
    # FIELD DERIVATIONS
    # ------------------------

    # pair_nums logic
    def pair_key(sgf)
      if sgf.length == 6
        sgf[0..1]
      else
        "0#{sgf[0..1]}"
      end
    end

    # sections calculation
    def calculate_sections(records)
      valid = records.select do |row|
        row["SGFLOCATION"][-2..] == "00"
      end

      (valid.count / 3.0).ceil
    end

  end
end
