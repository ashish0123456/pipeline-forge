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

ActiveRecord::Schema[8.1].define(version: 2026_11_08_000400) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "api_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.datetime "last_used_at"
    t.string "name", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "audit_events", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "auditable_id", null: false
    t.string "auditable_type", null: false
    t.datetime "created_at", null: false
    t.inet "ip_address"
    t.jsonb "metadata", default: {}, null: false
    t.string "request_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["auditable_type", "auditable_id", "created_at"], name: "index_audit_events_on_auditable_and_created"
    t.index ["user_id", "created_at"], name: "index_audit_events_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_audit_events_on_user_id"
  end

  create_table "execution_logs", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.bigint "job_run_id", null: false
    t.integer "sequence", null: false
    t.datetime "updated_at", null: false
    t.index ["job_run_id", "sequence"], name: "index_execution_logs_on_job_run_id_and_sequence", unique: true
    t.index ["job_run_id"], name: "index_execution_logs_on_job_run_id"
  end

  create_table "job_runs", force: :cascade do |t|
    t.integer "attempt", default: 0, null: false
    t.text "command_snapshot", null: false
    t.datetime "created_at", null: false
    t.integer "exit_code"
    t.text "failure_reason"
    t.datetime "finished_at"
    t.bigint "job_id", null: false
    t.string "job_name_snapshot", null: false
    t.bigint "pipeline_run_id", null: false
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_job_runs_on_job_id"
    t.index ["pipeline_run_id", "job_id"], name: "index_job_runs_on_pipeline_run_id_and_job_id", unique: true
    t.index ["pipeline_run_id", "status"], name: "index_job_runs_on_pipeline_run_id_and_status"
    t.index ["pipeline_run_id"], name: "index_job_runs_on_pipeline_run_id"
    t.check_constraint "attempt >= 0", name: "job_runs_attempt_valid"
    t.check_constraint "length(command_snapshot) <= 2000", name: "job_runs_command_snapshot_length_valid"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'running'::character varying::text, 'success'::character varying::text, 'failed'::character varying::text, 'cancelled'::character varying::text])", name: "job_runs_status_valid"
  end

  create_table "jobs", force: :cascade do |t|
    t.text "command", null: false
    t.datetime "created_at", null: false
    t.bigint "depends_on_ids", default: [], null: false, array: true
    t.integer "max_attempts", default: 3, null: false
    t.string "name", null: false
    t.bigint "pipeline_id", null: false
    t.integer "position", default: 0, null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["depends_on_ids"], name: "index_jobs_on_depends_on_ids", using: :gin
    t.index ["pipeline_id", "position"], name: "index_jobs_on_pipeline_id_and_position"
    t.index ["pipeline_id"], name: "index_jobs_on_pipeline_id"
    t.check_constraint "\"position\" >= 0", name: "jobs_position_valid"
    t.check_constraint "length(command) <= 2000", name: "jobs_command_length_valid"
    t.check_constraint "max_attempts >= 1 AND max_attempts <= 10", name: "jobs_max_attempts_valid"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'running'::character varying::text, 'success'::character varying::text, 'failed'::character varying::text])", name: "jobs_status_valid"
  end

  create_table "pipeline_runs", force: :cascade do |t|
    t.string "commit_sha", default: "legacy", null: false
    t.datetime "created_at", null: false
    t.text "failure_reason"
    t.datetime "finished_at"
    t.string "idempotency_key", null: false
    t.bigint "pipeline_id", null: false
    t.text "source_url", default: "", null: false
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["pipeline_id", "idempotency_key"], name: "index_pipeline_runs_on_pipeline_id_and_idempotency_key", unique: true
    t.index ["pipeline_id"], name: "index_pipeline_runs_on_one_active_pipeline", unique: true, where: "((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('running'::character varying)::text]))"
    t.index ["pipeline_id"], name: "index_pipeline_runs_on_pipeline_id"
    t.check_constraint "commit_sha::text = 'legacy'::text OR commit_sha::text ~ '^[a-fA-F0-9]{40}$'::text", name: "pipeline_runs_commit_sha_format_valid"
    t.check_constraint "commit_sha::text = 'legacy'::text OR length(commit_sha::text) = 40", name: "pipeline_runs_commit_sha_length_valid"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'running'::character varying::text, 'success'::character varying::text, 'failed'::character varying::text, 'cancelled'::character varying::text])", name: "pipeline_runs_status_valid"
  end

  create_table "pipelines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "project_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_pipelines_on_project_id"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'running'::character varying::text, 'success'::character varying::text, 'failed'::character varying::text])", name: "pipelines_status_valid"
  end

  create_table "project_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "project_id", null: false
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["project_id", "user_id"], name: "index_project_memberships_on_project_id_and_user_id", unique: true
    t.index ["project_id"], name: "index_project_memberships_on_project_id"
    t.index ["user_id"], name: "index_project_memberships_on_user_id"
    t.check_constraint "role::text = ANY (ARRAY['member'::character varying::text, 'maintainer'::character varying::text])", name: "project_memberships_role_valid"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "repository_url", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true
    t.check_constraint "role::text = ANY (ARRAY['member'::character varying::text, 'admin'::character varying::text])", name: "users_role_valid"
  end

  add_foreign_key "api_tokens", "users"
  add_foreign_key "audit_events", "users"
  add_foreign_key "execution_logs", "job_runs"
  add_foreign_key "job_runs", "jobs"
  add_foreign_key "job_runs", "pipeline_runs"
  add_foreign_key "jobs", "pipelines"
  add_foreign_key "pipeline_runs", "pipelines"
  add_foreign_key "pipelines", "projects"
  add_foreign_key "project_memberships", "projects"
  add_foreign_key "project_memberships", "users"
end
