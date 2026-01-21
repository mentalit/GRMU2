# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_01_20_210033) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "aisles", force: :cascade do |t|
    t.string "aisle_num"
    t.float "aisle_height"
    t.float "aisle_depth"
    t.float "aisle_section_width"
    t.integer "aisle_sections"
    t.bigint "pair_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pair_id"], name: "index_aisles_on_pair_id"
  end

  create_table "articles", force: :cascade do |t|
    t.integer "artno"
    t.string "artname_unicode"
    t.integer "baseonhand"
    t.integer "weight_g"
    t.string "slid_h"
    t.string "ssd"
    t.string "eds"
    t.string "hfb"
    t.float "expsale"
    t.string "pa"
    t.string "salesmethod"
    t.integer "rssq"
    t.string "sal_sol_indic"
    t.integer "mpq"
    t.integer "palq"
    t.integer "dt"
    t.float "cp_height"
    t.float "cp_length"
    t.float "cp_width"
    t.float "cp_diameter"
    t.float "cp_weight_gross"
    t.float "ul_height_gross"
    t.float "ul_length_gross"
    t.float "ul_width_gross"
    t.float "ul_diamter"
    t.string "new_assq"
    t.string "new_loc"
    t.integer "split_rssq"
    t.bigint "store_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "planned"
    t.bigint "section_id"
    t.string "plan_badge"
    t.bigint "level_id"
    t.boolean "part_planned", default: false, null: false
    t.integer "planned_quantity_remainder"
    t.integer "effective_dt"
    t.index ["level_id"], name: "index_articles_on_level_id"
    t.index ["section_id"], name: "index_articles_on_section_id"
    t.index ["store_id"], name: "index_articles_on_store_id"
  end

  create_table "levels", force: :cascade do |t|
    t.float "level_height"
    t.bigint "section_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "level_num"
    t.index ["section_id"], name: "index_levels_on_section_id"
  end

  create_table "pairs", force: :cascade do |t|
    t.string "pair_nums"
    t.float "pair_depth"
    t.float "pair_height"
    t.float "pair_section_width"
    t.integer "pair_sections"
    t.bigint "store_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["store_id"], name: "index_pairs_on_store_id"
  end

  create_table "placements", force: :cascade do |t|
    t.bigint "article_id", null: false
    t.bigint "section_id"
    t.bigint "level_id"
    t.decimal "planned_qty", precision: 10, scale: 2, null: false
    t.string "badge"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "width_used", precision: 10, scale: 2, null: false
    t.index ["article_id"], name: "index_placements_on_article_id"
    t.index ["level_id"], name: "index_placements_on_level_id"
    t.index ["section_id"], name: "index_placements_on_section_id"
  end

  create_table "planned_placements", force: :cascade do |t|
    t.bigint "article_id", null: false
    t.bigint "aisle_id", null: false
    t.bigint "section_id", null: false
    t.bigint "level_id", null: false
    t.decimal "qty", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["aisle_id"], name: "index_planned_placements_on_aisle_id"
    t.index ["article_id"], name: "index_planned_placements_on_article_id"
    t.index ["level_id"], name: "index_planned_placements_on_level_id"
    t.index ["section_id"], name: "index_planned_placements_on_section_id"
  end

  create_table "sections", force: :cascade do |t|
    t.integer "section_num"
    t.float "section_depth"
    t.float "section_height"
    t.float "section_width"
    t.bigint "aisle_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["aisle_id"], name: "index_sections_on_aisle_id"
  end

  create_table "stores", force: :cascade do |t|
    t.string "store_loc"
    t.integer "store_num"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "aisles", "pairs"
  add_foreign_key "articles", "levels"
  add_foreign_key "articles", "sections"
  add_foreign_key "articles", "stores"
  add_foreign_key "levels", "sections"
  add_foreign_key "pairs", "stores"
  add_foreign_key "placements", "articles"
  add_foreign_key "placements", "levels"
  add_foreign_key "placements", "sections"
  add_foreign_key "planned_placements", "aisles"
  add_foreign_key "planned_placements", "articles"
  add_foreign_key "planned_placements", "levels"
  add_foreign_key "planned_placements", "sections"
  add_foreign_key "sections", "aisles"
end
