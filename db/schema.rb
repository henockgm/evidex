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

ActiveRecord::Schema[8.1].define(version: 2026_10_21_125515) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_usages", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "feature", null: false
    t.string "model", null: false
    t.integer "input_tokens", default: 0, null: false
    t.integer "output_tokens", default: 0, null: false
    t.integer "latency_ms"
    t.boolean "succeeded", default: true, null: false
    t.datetime "created_at", null: false
    t.index ["user_id", "feature", "created_at"], name: "index_ai_usages_on_user_id_and_feature_and_created_at"
    t.index ["user_id"], name: "index_ai_usages_on_user_id"
  end

  create_table "application_contacts", force: :cascade do |t|
    t.bigint "job_application_id", null: false
    t.string "name", null: false
    t.string "role"
    t.string "email"
    t.string "phone"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_application_id"], name: "index_application_contacts_on_job_application_id"
  end

  create_table "audit_events", force: :cascade do |t|
    t.bigint "user_id"
    t.string "action", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["user_id", "created_at"], name: "index_audit_events_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_audit_events_on_user_id"
  end

  create_table "document_chunks", force: :cascade do |t|
    t.bigint "document_id", null: false
    t.bigint "user_id", null: false
    t.integer "position", null: false
    t.integer "page"
    t.string "section"
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.vector "embedding", limit: 384
    t.string "embedding_model"
    t.virtual "search_vector", type: :tsvector, as: "to_tsvector('simple'::regconfig, (((COALESCE(section, ''::character varying))::text || ' '::text) || content))", stored: true
    t.index ["document_id", "position"], name: "index_document_chunks_on_document_id_and_position", unique: true
    t.index ["document_id"], name: "index_document_chunks_on_document_id"
    t.index ["embedding"], name: "index_document_chunks_on_embedding", opclass: :vector_cosine_ops, using: :hnsw
    t.index ["search_vector"], name: "index_document_chunks_on_search_vector", using: :gin
    t.index ["user_id"], name: "index_document_chunks_on_user_id"
  end

  create_table "documents", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.string "kind", default: "cv", null: false
    t.boolean "primary", default: false, null: false
    t.string "status", default: "pending", null: false
    t.string "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "text_pages", default: [], null: false
    t.integer "character_count", default: 0, null: false
    t.datetime "processed_at"
    t.index ["user_id", "created_at"], name: "index_documents_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_documents_on_user_id"
    t.index ["user_id"], name: "index_documents_one_primary_per_user", unique: true, where: "\"primary\""
  end

  create_table "identities", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "provider", null: false
    t.string "uid", null: false
    t.string "email"
    t.boolean "email_verified", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "uid"], name: "index_identities_on_provider_and_uid", unique: true
    t.index ["user_id", "provider"], name: "index_identities_on_user_id_and_provider", unique: true
    t.index ["user_id"], name: "index_identities_on_user_id"
  end

  create_table "interviews", force: :cascade do |t|
    t.bigint "job_application_id", null: false
    t.string "round"
    t.datetime "scheduled_at", null: false
    t.string "format"
    t.string "location"
    t.string "status", default: "scheduled", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_application_id", "scheduled_at"], name: "index_interviews_on_job_application_id_and_scheduled_at"
    t.index ["job_application_id"], name: "index_interviews_on_job_application_id"
    t.index ["status", "scheduled_at"], name: "index_interviews_on_status_and_scheduled_at"
  end

  create_table "job_application_events", force: :cascade do |t|
    t.bigint "job_application_id", null: false
    t.string "from_status"
    t.string "to_status", null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.index ["job_application_id"], name: "index_job_application_events_on_job_application_id"
  end

  create_table "job_applications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "job_posting_id", null: false
    t.string "status", default: "saved", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "applied_on"
    t.string "next_action"
    t.date "next_action_on"
    t.text "notes"
    t.jsonb "links", default: [], null: false
    t.index ["job_posting_id"], name: "index_job_applications_on_job_posting_id", unique: true
    t.index ["user_id", "next_action_on"], name: "index_job_applications_on_user_id_and_next_action_on"
    t.index ["user_id", "status"], name: "index_job_applications_on_user_id_and_status"
    t.index ["user_id"], name: "index_job_applications_on_user_id"
  end

  create_table "job_postings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.string "company", null: false
    t.string "location"
    t.string "work_model"
    t.date "deadline"
    t.string "source_url"
    t.text "description", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "employment_type"
    t.string "seniority"
    t.string "salary"
    t.jsonb "keywords", default: [], null: false
    t.string "extraction_status", default: "none", null: false
    t.string "extraction_error"
    t.datetime "extracted_at"
    t.index ["user_id", "created_at"], name: "index_job_postings_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_job_postings_on_user_id"
  end

  create_table "match_citations", force: :cascade do |t|
    t.bigint "requirement_match_id", null: false
    t.bigint "document_chunk_id"
    t.bigint "document_id"
    t.string "document_title", null: false
    t.integer "page"
    t.string "section"
    t.text "excerpt", null: false
    t.datetime "created_at", null: false
    t.index ["document_chunk_id"], name: "index_match_citations_on_document_chunk_id"
    t.index ["document_id"], name: "index_match_citations_on_document_id"
    t.index ["requirement_match_id"], name: "index_match_citations_on_requirement_match_id"
  end

  create_table "match_reports", force: :cascade do |t|
    t.bigint "job_posting_id", null: false
    t.bigint "user_id", null: false
    t.integer "version", null: false
    t.string "status", default: "pending", null: false
    t.string "error"
    t.string "model"
    t.jsonb "strengths", default: [], null: false
    t.jsonb "gaps", default: [], null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_posting_id", "version"], name: "index_match_reports_on_job_posting_id_and_version", unique: true
    t.index ["job_posting_id"], name: "index_match_reports_on_job_posting_id"
    t.index ["user_id"], name: "index_match_reports_on_user_id"
  end

  create_table "requirement_matches", force: :cascade do |t|
    t.bigint "match_report_id", null: false
    t.bigint "requirement_id"
    t.string "requirement_kind", null: false
    t.text "requirement_text", null: false
    t.string "verdict", null: false
    t.text "reasoning"
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["match_report_id"], name: "index_requirement_matches_on_match_report_id"
    t.index ["requirement_id"], name: "index_requirement_matches_on_requirement_id"
  end

  create_table "requirements", force: :cascade do |t|
    t.bigint "job_posting_id", null: false
    t.string "kind", null: false
    t.text "text", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_posting_id", "kind", "position"], name: "index_requirements_on_job_posting_id_and_kind_and_position"
    t.index ["job_posting_id"], name: "index_requirements_on_job_posting_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token_digest", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "last_active_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_sessions_on_token_digest", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "name"
    t.string "password_digest"
    t.datetime "email_verified_at"
    t.integer "failed_sign_in_count", default: 0, null: false
    t.integer "lockout_count", default: 0, null: false
    t.datetime "locked_until"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_usages", "users", on_delete: :cascade
  add_foreign_key "application_contacts", "job_applications", on_delete: :cascade
  add_foreign_key "audit_events", "users"
  add_foreign_key "document_chunks", "documents", on_delete: :cascade
  add_foreign_key "document_chunks", "users", on_delete: :cascade
  add_foreign_key "documents", "users", on_delete: :cascade
  add_foreign_key "identities", "users"
  add_foreign_key "interviews", "job_applications", on_delete: :cascade
  add_foreign_key "job_application_events", "job_applications", on_delete: :cascade
  add_foreign_key "job_applications", "job_postings", on_delete: :cascade
  add_foreign_key "job_applications", "users"
  add_foreign_key "job_postings", "users"
  add_foreign_key "match_citations", "document_chunks", on_delete: :nullify
  add_foreign_key "match_citations", "documents", on_delete: :nullify
  add_foreign_key "match_citations", "requirement_matches", on_delete: :cascade
  add_foreign_key "match_reports", "job_postings", on_delete: :cascade
  add_foreign_key "match_reports", "users", on_delete: :cascade
  add_foreign_key "requirement_matches", "match_reports", on_delete: :cascade
  add_foreign_key "requirement_matches", "requirements", on_delete: :nullify
  add_foreign_key "requirements", "job_postings", on_delete: :cascade
  add_foreign_key "sessions", "users"
end
