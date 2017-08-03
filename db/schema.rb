# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170801192038) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "uuid-ossp"

  create_table "annotations", primary_key: "uuid", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "change_uuid", null: false
    t.integer "author_id", null: false
    t.jsonb "annotation", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_annotations_on_author_id"
    t.index ["change_uuid"], name: "index_annotations_on_change_uuid"
  end

  create_table "changes", primary_key: "uuid", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "uuid_from", null: false
    t.uuid "uuid_to", null: false
    t.float "priority"
    t.jsonb "current_annotation"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "significance"
    t.index ["uuid_to", "uuid_from"], name: "index_changes_on_uuid_to_and_uuid_from", unique: true
    t.index ["uuid_to"], name: "index_changes_on_uuid_to"
  end

  create_table "imports", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.integer "status", default: 0, null: false
    t.string "file"
    t.jsonb "processing_errors"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "update_behavior", default: 0, null: false
    t.index ["user_id"], name: "index_imports_on_user_id"
  end

  create_table "invitations", id: :serial, force: :cascade do |t|
    t.integer "issuer_id"
    t.integer "redeemer_id"
    t.string "code"
    t.string "email"
    t.datetime "expires_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_invitations_on_code"
    t.index ["issuer_id"], name: "index_invitations_on_issuer_id"
    t.index ["redeemer_id"], name: "index_invitations_on_redeemer_id"
  end

  create_table "pages", primary_key: "uuid", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "url", null: false
    t.string "title"
    t.string "agency"
    t.string "site"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["url"], name: "index_pages_on_url"
    t.index ["uuid", "site"], name: "index_pages_on_uuid_and_site"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.boolean "admin", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "versions", primary_key: "uuid", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "page_uuid", null: false
    t.datetime "capture_time", null: false
    t.string "uri"
    t.string "version_hash"
    t.string "source_type"
    t.jsonb "source_metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["capture_time"], name: "index_versions_on_capture_time"
    t.index ["page_uuid"], name: "index_versions_on_page_uuid"
    t.index ["version_hash"], name: "index_versions_on_version_hash"
  end

  add_foreign_key "annotations", "users", column: "author_id"
  add_foreign_key "changes", "versions", column: "uuid_from", primary_key: "uuid"
  add_foreign_key "changes", "versions", column: "uuid_to", primary_key: "uuid"
  add_foreign_key "imports", "users"
  add_foreign_key "invitations", "users", column: "issuer_id"
  add_foreign_key "invitations", "users", column: "redeemer_id"
  add_foreign_key "versions", "pages", column: "page_uuid", primary_key: "uuid"
end
