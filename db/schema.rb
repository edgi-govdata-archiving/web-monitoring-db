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

ActiveRecord::Schema[8.1].define(version: 2026_02_02_203260) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"
  enable_extension "uuid-ossp"

  create_table "annotations", primary_key: "uuid", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.jsonb "annotation", null: false
    t.bigint "author_id", null: false
    t.uuid "change_uuid", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["author_id"], name: "index_annotations_on_author_id"
    t.index ["change_uuid"], name: "index_annotations_on_change_uuid"
  end

  create_table "changes", primary_key: "uuid", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.jsonb "current_annotation"
    t.float "priority"
    t.float "significance"
    t.datetime "updated_at", precision: nil, null: false
    t.uuid "uuid_from", null: false
    t.uuid "uuid_to", null: false
    t.index ["uuid_to", "uuid_from"], name: "index_changes_on_uuid_to_and_uuid_from", unique: true
    t.index ["uuid_to"], name: "index_changes_on_uuid_to"
  end

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "callback_priority"
    t.text "callback_queue_name"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "discarded_at"
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
    t.text "on_discard"
    t.text "on_finish"
    t.text "on_success"
    t.jsonb "serialized_properties"
    t.datetime "updated_at", null: false
  end

  create_table "good_job_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "active_job_id", null: false
    t.datetime "created_at", null: false
    t.interval "duration"
    t.text "error"
    t.text "error_backtrace", array: true
    t.integer "error_event", limit: 2
    t.datetime "finished_at"
    t.text "job_class"
    t.uuid "process_id"
    t.text "queue_name"
    t.datetime "scheduled_at"
    t.jsonb "serialized_params"
    t.datetime "updated_at", null: false
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "lock_type", limit: 2
    t.jsonb "state"
    t.datetime "updated_at", null: false
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "key"
    t.datetime "updated_at", null: false
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "active_job_id"
    t.uuid "batch_callback_id"
    t.uuid "batch_id"
    t.text "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "cron_at"
    t.text "cron_key"
    t.text "error"
    t.integer "error_event", limit: 2
    t.integer "executions_count"
    t.datetime "finished_at"
    t.boolean "is_discrete"
    t.text "job_class"
    t.text "labels", array: true
    t.datetime "locked_at"
    t.uuid "locked_by_id"
    t.datetime "performed_at"
    t.integer "priority"
    t.text "queue_name"
    t.uuid "retried_good_job_id"
    t.datetime "scheduled_at"
    t.jsonb "serialized_params"
    t.datetime "updated_at", null: false
    t.index ["active_job_id", "created_at"], name: "index_good_jobs_on_active_job_id_and_created_at"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id", where: "(batch_callback_id IS NOT NULL)"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id", where: "(batch_id IS NOT NULL)"
    t.index ["concurrency_key", "created_at"], name: "index_good_jobs_on_concurrency_key_and_created_at"
    t.index ["concurrency_key"], name: "index_good_jobs_on_concurrency_key_when_unfinished", where: "(finished_at IS NULL)"
    t.index ["cron_key", "created_at"], name: "index_good_jobs_on_cron_key_and_created_at_cond", where: "(cron_key IS NOT NULL)"
    t.index ["cron_key", "cron_at"], name: "index_good_jobs_on_cron_key_and_cron_at_cond", unique: true, where: "(cron_key IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_jobs_on_finished_at_only", where: "(finished_at IS NOT NULL)"
    t.index ["job_class"], name: "index_good_jobs_on_job_class"
    t.index ["labels"], name: "index_good_jobs_on_labels", where: "(labels IS NOT NULL)", using: :gin
    t.index ["locked_by_id"], name: "index_good_jobs_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
    t.index ["priority", "created_at"], name: "index_good_job_jobs_for_candidate_lookup", where: "(finished_at IS NULL)"
    t.index ["priority", "created_at"], name: "index_good_jobs_jobs_on_priority_created_at_when_unfinished", order: { priority: "DESC NULLS LAST" }, where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at"], name: "index_good_jobs_on_priority_scheduled_at_unfinished_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "scheduled_at"], name: "index_good_jobs_on_queue_name_and_scheduled_at", where: "(finished_at IS NULL)"
    t.index ["scheduled_at"], name: "index_good_jobs_on_scheduled_at", where: "(finished_at IS NULL)"
  end

  create_table "imports", force: :cascade do |t|
    t.boolean "create_pages", default: true, null: false
    t.datetime "created_at", precision: nil, null: false
    t.string "file"
    t.jsonb "processing_errors"
    t.jsonb "processing_warnings"
    t.boolean "skip_unchanged_versions", default: false, null: false
    t.integer "status", default: 0, null: false
    t.integer "update_behavior", default: 0, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "user_id"
    t.index ["user_id"], name: "index_imports_on_user_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", precision: nil, null: false
    t.string "email"
    t.datetime "expires_on", precision: nil
    t.bigint "issuer_id"
    t.bigint "redeemer_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["code"], name: "index_invitations_on_code"
    t.index ["issuer_id"], name: "index_invitations_on_issuer_id"
    t.index ["redeemer_id"], name: "index_invitations_on_redeemer_id"
  end

  create_table "maintainers", primary_key: "uuid", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.citext "name", null: false
    t.uuid "parent_uuid"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["name"], name: "index_maintainers_on_name", unique: true
  end

  create_table "maintainerships", id: false, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.uuid "maintainer_uuid", null: false
    t.uuid "page_uuid", null: false
    t.index ["maintainer_uuid", "page_uuid"], name: "index_maintainerships_on_maintainer_uuid_and_page_uuid", unique: true
    t.index ["maintainer_uuid"], name: "index_maintainerships_on_maintainer_uuid"
    t.index ["page_uuid"], name: "index_maintainerships_on_page_uuid"
  end

  create_table "merged_pages", primary_key: "uuid", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.jsonb "audit_data"
    t.uuid "target_uuid", null: false
    t.index ["target_uuid"], name: "index_merged_pages_on_target_uuid"
  end

  create_table "page_urls", primary_key: "uuid", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "from_time", precision: nil, default: -::Float::INFINITY, null: false
    t.string "notes"
    t.uuid "page_uuid", null: false
    t.datetime "to_time", precision: nil, default: ::Float::INFINITY, null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.string "url_key", null: false
    t.index ["page_uuid", "url", "from_time", "to_time"], name: "index_page_urls_on_page_uuid_and_url_and_from_time_and_to_time", unique: true
    t.index ["url"], name: "index_page_urls_on_url"
    t.index ["url_key"], name: "index_page_urls_on_url_key"
  end

  create_table "pages", primary_key: "uuid", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", precision: nil, null: false
    t.integer "status"
    t.string "title"
    t.datetime "updated_at", precision: nil, null: false
    t.string "url", null: false
    t.string "url_key"
    t.index ["url"], name: "index_pages_on_url"
    t.index ["url_key"], name: "index_pages_on_url_key"
  end

  create_table "taggings", id: false, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.uuid "tag_uuid", null: false
    t.string "taggable_type"
    t.uuid "taggable_uuid", null: false
    t.index ["tag_uuid"], name: "index_taggings_on_tag_uuid"
    t.index ["taggable_uuid", "tag_uuid"], name: "index_taggings_on_taggable_uuid_and_tag_uuid", unique: true
    t.index ["taggable_uuid"], name: "index_taggings_on_taggable_uuid"
  end

  create_table "tags", primary_key: "uuid", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.citext "name", null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "confirmation_sent_at", precision: nil
    t.string "confirmation_token"
    t.datetime "confirmed_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.inet "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "last_sign_in_at", precision: nil
    t.inet "last_sign_in_ip"
    t.string "permissions", default: [], array: true
    t.datetime "remember_created_at", precision: nil
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.string "unconfirmed_email"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "versions", primary_key: "uuid", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "body_hash"
    t.string "body_url"
    t.datetime "capture_time", precision: nil, null: false
    t.integer "content_length"
    t.datetime "created_at", precision: nil, null: false
    t.boolean "different", default: true
    t.jsonb "headers"
    t.string "media_type"
    t.string "network_error"
    t.uuid "page_uuid"
    t.jsonb "source_metadata"
    t.string "source_type"
    t.integer "status"
    t.string "title"
    t.datetime "updated_at", precision: nil, null: false
    t.string "url"
    t.index ["body_hash"], name: "index_versions_on_body_hash"
    t.index ["capture_time", "uuid"], name: "index_versions_on_capture_time_and_uuid"
    t.index ["created_at", "uuid"], name: "index_versions_on_created_at_and_uuid"
    t.index ["page_uuid", "capture_time", "uuid"], name: "index_versions_on_page_uuid_and_capture_time_and_uuid"
    t.index ["page_uuid", "created_at", "uuid"], name: "index_versions_on_page_uuid_and_created_at_and_uuid"
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
