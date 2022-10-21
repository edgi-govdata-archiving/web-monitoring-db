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

ActiveRecord::Schema[7.0].define(version: 2022_09_01_211031) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pgcrypto"
  enable_extension "plpgsql"
  enable_extension "uuid-ossp"

  create_table "annotations", primary_key: "uuid", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "change_uuid", null: false
    t.integer "author_id", null: false
    t.jsonb "annotation", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["author_id"], name: "index_annotations_on_author_id"
    t.index ["change_uuid"], name: "index_annotations_on_change_uuid"
  end

  create_table "changes", primary_key: "uuid", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "uuid_from", null: false
    t.uuid "uuid_to", null: false
    t.float "priority"
    t.jsonb "current_annotation"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.float "significance"
    t.index ["uuid_to", "uuid_from"], name: "index_changes_on_uuid_to_and_uuid_from", unique: true
    t.index ["uuid_to"], name: "index_changes_on_uuid_to"
  end

  create_table "imports", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.integer "status", default: 0, null: false
    t.string "file"
    t.jsonb "processing_errors"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "update_behavior", default: 0, null: false
    t.boolean "create_pages", default: true, null: false
    t.jsonb "processing_warnings"
    t.boolean "skip_unchanged_versions", default: false, null: false
    t.index ["user_id"], name: "index_imports_on_user_id"
  end

  create_table "invitations", id: :serial, force: :cascade do |t|
    t.integer "issuer_id"
    t.integer "redeemer_id"
    t.string "code"
    t.string "email"
    t.datetime "expires_on", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["code"], name: "index_invitations_on_code"
    t.index ["issuer_id"], name: "index_invitations_on_issuer_id"
    t.index ["redeemer_id"], name: "index_invitations_on_redeemer_id"
  end

  create_table "maintainers", primary_key: "uuid", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.citext "name", null: false
    t.uuid "parent_uuid"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["name"], name: "index_maintainers_on_name", unique: true
  end

  create_table "maintainerships", id: false, force: :cascade do |t|
    t.uuid "maintainer_uuid", null: false
    t.uuid "page_uuid", null: false
    t.datetime "created_at", precision: nil, null: false
    t.index ["maintainer_uuid", "page_uuid"], name: "index_maintainerships_on_maintainer_uuid_and_page_uuid", unique: true
    t.index ["maintainer_uuid"], name: "index_maintainerships_on_maintainer_uuid"
    t.index ["page_uuid"], name: "index_maintainerships_on_page_uuid"
  end

  create_table "merged_pages", primary_key: "uuid", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "target_uuid", null: false
    t.jsonb "audit_data"
    t.index ["target_uuid"], name: "index_merged_pages_on_target_uuid"
  end

  create_table "page_urls", primary_key: "uuid", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "page_uuid", null: false
    t.string "url", null: false
    t.string "url_key", null: false
    t.datetime "from_time", precision: nil, default: -::Float::INFINITY, null: false
    t.datetime "to_time", precision: nil, default: ::Float::INFINITY, null: false
    t.string "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["page_uuid", "url", "from_time", "to_time"], name: "index_page_urls_on_page_uuid_and_url_and_from_time_and_to_time", unique: true
    t.index ["url"], name: "index_page_urls_on_url"
    t.index ["url_key"], name: "index_page_urls_on_url_key"
  end

  create_table "pages", primary_key: "uuid", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "url", null: false
    t.string "title"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "url_key"
    t.boolean "active", default: true
    t.integer "status"
    t.index ["url"], name: "index_pages_on_url"
    t.index ["url_key"], name: "index_pages_on_url_key"
  end

  create_table "taggings", id: false, force: :cascade do |t|
    t.uuid "taggable_uuid", null: false
    t.string "taggable_type"
    t.uuid "tag_uuid", null: false
    t.datetime "created_at", precision: nil, null: false
    t.index ["tag_uuid"], name: "index_taggings_on_tag_uuid"
    t.index ["taggable_uuid", "tag_uuid"], name: "index_taggings_on_taggable_uuid_and_tag_uuid", unique: true
    t.index ["taggable_uuid"], name: "index_taggings_on_taggable_uuid"
  end

  create_table "tags", primary_key: "uuid", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.citext "name", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at", precision: nil
    t.datetime "confirmation_sent_at", precision: nil
    t.string "unconfirmed_email"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "permissions", default: [], array: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "versions", primary_key: "uuid", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "page_uuid"
    t.datetime "capture_time", precision: nil, null: false
    t.string "body_url"
    t.string "body_hash"
    t.string "source_type"
    t.jsonb "source_metadata"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "title"
    t.string "url"
    t.boolean "different", default: true
    t.integer "status"
    t.integer "content_length"
    t.string "media_type"
    t.jsonb "headers"
    t.index ["body_hash"], name: "index_versions_on_body_hash"
    t.index ["capture_time"], name: "index_different_versions_on_capture_time", where: "(different = true)"
    t.index ["capture_time"], name: "index_versions_on_capture_time"
    t.index ["created_at"], name: "index_different_versions_on_created_at", where: "(different = true)"
    t.index ["created_at"], name: "index_versions_on_created_at"
    t.index ["page_uuid"], name: "index_versions_on_page_uuid"
    t.index ["source_type"], name: "index_versions_on_source_type"
  end

  add_foreign_key "annotations", "users", column: "author_id"
  add_foreign_key "changes", "versions", column: "uuid_from", primary_key: "uuid"
  add_foreign_key "changes", "versions", column: "uuid_to", primary_key: "uuid"
  add_foreign_key "imports", "users"
  add_foreign_key "invitations", "users", column: "issuer_id"
  add_foreign_key "invitations", "users", column: "redeemer_id"
  add_foreign_key "maintainerships", "maintainers", column: "maintainer_uuid", primary_key: "uuid"
  add_foreign_key "maintainerships", "pages", column: "page_uuid", primary_key: "uuid"
  add_foreign_key "page_urls", "pages", column: "page_uuid", primary_key: "uuid"
  add_foreign_key "taggings", "tags", column: "tag_uuid", primary_key: "uuid"
  add_foreign_key "versions", "pages", column: "page_uuid", primary_key: "uuid"
end
