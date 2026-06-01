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

ActiveRecord::Schema[8.1].define(version: 3) do
  create_table "items", force: :cascade do |t|
    t.decimal "cost", precision: 8, scale: 2
    t.datetime "created_at", null: false
    t.string "description"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "stock_transactions", force: :cascade do |t|
    t.string "batch_number"
    t.integer "item_id", null: false
    t.integer "operation_id"
    t.string "operation_type"
    t.integer "quantity", null: false
    t.integer "storage_id", null: false
    t.datetime "time_at"
    t.decimal "unit_cost", precision: 10, scale: 2
    t.index ["storage_id", "item_id", "batch_number"], name: "idx_on_storage_id_item_id_batch_number_e7f09aad11"
  end

  create_table "storages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "location"
    t.string "name"
    t.datetime "updated_at", null: false
  end
end
