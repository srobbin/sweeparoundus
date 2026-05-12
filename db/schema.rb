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

ActiveRecord::Schema[7.2].define(version: 2026_05_12_040000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "postgis"

  create_table "admin_users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "alerts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email"
    t.string "phone"
    t.boolean "confirmed", default: false
    t.uuid "area_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "street_address"
    t.decimal "lat", precision: 10, scale: 6
    t.decimal "lng", precision: 10, scale: 6
    t.boolean "permit_notifications", default: true, null: false
    t.geography "location", limit: {srid: 4326, type: "st_point", geographic: true}
    t.index ["area_id"], name: "index_alerts_on_area_id"
    t.index ["email", "street_address"], name: "index_alerts_on_subscription_uniqueness", unique: true
    t.index ["email"], name: "index_alerts_on_email"
    t.index ["location"], name: "index_alerts_on_location", using: :gist
  end

  create_table "areas", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "number"
    t.integer "ward"
    t.geometry "shape", limit: {srid: 0, type: "geometry"}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
    t.string "shortcode"
    t.index ["shortcode"], name: "index_areas_on_shortcode", unique: true
    t.index ["slug"], name: "index_areas_on_slug", unique: true
  end

  create_table "cdot_permits", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "unique_key", null: false
    t.string "application_number"
    t.string "application_name"
    t.string "application_type"
    t.string "application_description"
    t.string "work_type"
    t.string "work_type_description"
    t.string "application_status"
    t.datetime "application_start_date"
    t.datetime "application_end_date"
    t.datetime "application_expire_date"
    t.datetime "application_issued_date"
    t.text "detail"
    t.string "parking_meter_posting_or_bagging"
    t.integer "street_number_from"
    t.integer "street_number_to"
    t.string "direction"
    t.string "street_name"
    t.string "suffix"
    t.text "placement"
    t.string "street_closure"
    t.integer "ward"
    t.decimal "x_coordinate", precision: 12, scale: 4
    t.decimal "y_coordinate", precision: 12, scale: 4
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.geography "location", limit: {srid: 4326, type: "st_point", geographic: true}
    t.datetime "data_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "processed_alert_ids", default: []
    t.datetime "notifications_sent_at"
    t.decimal "segment_from_lat", precision: 10, scale: 6
    t.decimal "segment_from_lng", precision: 10, scale: 6
    t.decimal "segment_to_lat", precision: 10, scale: 6
    t.decimal "segment_to_lng", precision: 10, scale: 6
    t.index ["application_expire_date"], name: "index_cdot_permits_on_application_expire_date"
    t.index ["application_number"], name: "index_cdot_permits_on_application_number"
    t.index ["application_start_date"], name: "index_cdot_permits_on_application_start_date"
    t.index ["application_status"], name: "index_cdot_permits_on_application_status"
    t.index ["data_synced_at"], name: "index_cdot_permits_on_data_synced_at"
    t.index ["location"], name: "index_cdot_permits_on_location", using: :gist
    t.index ["notifications_sent_at"], name: "index_cdot_permits_on_notifications_sent_at"
    t.index ["parking_meter_posting_or_bagging"], name: "index_cdot_permits_on_parking_meter"
    t.index ["unique_key"], name: "index_cdot_permits_on_unique_key", unique: true
    t.index ["ward"], name: "index_cdot_permits_on_ward"
  end

  create_table "sweeps", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.date "date_1"
    t.date "date_2"
    t.date "date_3"
    t.date "date_4"
    t.uuid "area_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["area_id"], name: "index_sweeps_on_area_id"
  end

  add_foreign_key "alerts", "areas"
  add_foreign_key "sweeps", "areas"
end
