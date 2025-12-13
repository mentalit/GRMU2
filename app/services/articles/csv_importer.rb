# app/services/articles/csv_importer.rb
require "csv"

module Articles
  class CsvImporter
    def self.import(csv1, csv2, store:)
      merged_rows = {}

      # 1️⃣ Read FIRST CSV — establish allowed ARTNOs
      allowed_artnos = Set.new

     CSV.foreach(csv1.path, headers: true) do |row|
        attrs = normalize_row(row)
        artno = attrs[:artno]

        next unless artno
        next if skip_row?(attrs)

        allowed_artnos << artno
        merged_rows[artno] = attrs
      end

      # 2️⃣ Read SECOND CSV — only merge if ARTNO exists in CSV #1
      CSV.foreach(csv2.path, headers: true) do |row|
        attrs = normalize_row(row)
        artno = attrs[:artno]

        next unless artno
        next unless allowed_artnos.include?(artno)

        merged_rows[artno].merge!(attrs.compact)

      end

      upsert_articles(merged_rows.values, store)
    end

    # --------------------
    # Helpers (unchanged)
    # --------------------

    def self.normalize_row(row)
      row.to_h
         .transform_keys { |k| k.to_s.strip.downcase }
         .symbolize_keys
         .tap { |h| cast_types!(h) }
    end

    def self.cast_types!(hash)
      integer_fields = %i[artno baseonhand weight_g rssq mpq palq dt]
      float_fields   = %i[
        expsale cp_height cp_length cp_width cp_diameter
        cp_weight_gross ul_height_gross ul_length_gross
        ul_width_gross ul_diamter
      ]
      date_fields = %i[ssd eds]

      integer_fields.each { |f| hash[f] = hash[f].to_i if hash[f].present? }
      float_fields.each   { |f| hash[f] = hash[f].to_f if hash[f].present? }
      date_fields.each    { |f| hash[f] = Date.parse(hash[f]) rescue nil }
    end

    def self.skip_row?(attrs)
        salesmethod = attrs[:salesmethod].to_i
        baseonhand  = attrs[:baseonhand].to_i
        eds         = attrs[:eds]

        # Rule 1: salesmethod 0 or 3
        return true if salesmethod == 0 || salesmethod == 3

        # Rule 2: expired AND low stock
        if eds.present?
          return true if eds < Date.today && baseonhand < 5
        end

        false
      end

    def self.upsert_articles(records, store)
      allowed_attributes =
        Article.column_names.map(&:to_sym) -
        %i[id created_at updated_at]

      records.each do |attrs|
        filtered_attrs = attrs.slice(*allowed_attributes)

        article = store.articles.find_or_initialize_by(
          artno: filtered_attrs[:artno]
        )

        article.assign_attributes(filtered_attrs)
        article.save!
      end
    end
  end
end
