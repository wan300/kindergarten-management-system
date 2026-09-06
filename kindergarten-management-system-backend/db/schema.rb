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

ActiveRecord::Schema[7.0].define(version: 2026_09_06_000200) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.integer "record_id", null: false
    t.integer "blob_id", null: false
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
    t.integer "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admins", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "phone_number"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
  end

  create_table "attendances", force: :cascade do |t|
    t.integer "classroom_id"
    t.integer "student_id"
    t.string "student_name"
    t.string "status"
    t.date "date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["classroom_id"], name: "index_attendances_on_classroom_id"
    t.index ["student_id", "date"], name: "index_attendances_on_student_id_and_date", unique: true
  end

  create_table "child_chat_messages", force: :cascade do |t|
    t.integer "child_chat_session_id", null: false
    t.string "role", null: false
    t.text "content", null: false
    t.string "model"
    t.integer "prompt_tokens"
    t.integer "completion_tokens"
    t.integer "total_tokens"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["child_chat_session_id", "created_at"], name: "index_child_chat_messages_on_session_and_created_at"
    t.index ["child_chat_session_id"], name: "index_child_chat_messages_on_child_chat_session_id"
  end

  create_table "child_chat_sessions", force: :cascade do |t|
    t.integer "student_id", null: false
    t.integer "parent_id"
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "child_device_id"
    t.string "source", default: "web", null: false
    t.string "external_session_id"
    t.string "device_binding_id"
    t.integer "device_binding_epoch"
    t.index ["child_device_id", "device_binding_epoch", "external_session_id"], name: "index_child_chat_sessions_on_device_binding_and_external_id", unique: true
    t.index ["child_device_id"], name: "index_child_chat_sessions_on_child_device_id"
    t.index ["parent_id"], name: "index_child_chat_sessions_on_parent_id"
    t.index ["student_id", "created_at"], name: "index_child_chat_sessions_on_student_id_and_created_at"
    t.index ["student_id"], name: "index_child_chat_sessions_on_student_id"
  end

  create_table "child_devices", force: :cascade do |t|
    t.string "device_id", null: false
    t.integer "student_id", null: false
    t.string "binding_id", null: false
    t.integer "binding_epoch", default: 1, null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["binding_id"], name: "index_child_devices_on_binding_id", unique: true
    t.index ["device_id"], name: "index_child_devices_on_device_id", unique: true
    t.index ["student_id"], name: "index_child_devices_on_student_id"
  end

  create_table "child_tts_audios", force: :cascade do |t|
    t.integer "child_chat_message_id"
    t.string "audio_cache_key", null: false
    t.string "provider", default: "tencent_cloud", null: false
    t.integer "voice_type", null: false
    t.string "codec", null: false
    t.integer "sample_rate", null: false
    t.string "text_digest", null: false
    t.text "clean_text", null: false
    t.text "audio_segments", null: false
    t.integer "audio_bytes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["audio_cache_key"], name: "index_child_tts_audios_on_audio_cache_key", unique: true
    t.index ["child_chat_message_id"], name: "index_child_tts_audios_on_child_chat_message_id"
    t.index ["provider", "voice_type", "codec", "sample_rate", "text_digest"], name: "index_child_tts_audios_on_voice_and_text"
  end

  create_table "classrooms", force: :cascade do |t|
    t.string "name"
    t.integer "teacher_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["teacher_id"], name: "index_classrooms_on_teacher_id", unique: true, where: "teacher_id IS NOT NULL"
  end

  create_table "device_chat_turns", force: :cascade do |t|
    t.integer "child_chat_session_id", null: false
    t.string "turn_id", null: false
    t.text "content", null: false
    t.string "status", null: false
    t.integer "attempt_count", default: 1, null: false
    t.integer "user_message_id"
    t.integer "assistant_message_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assistant_message_id"], name: "index_device_chat_turns_on_assistant_message_id"
    t.index ["child_chat_session_id", "status"], name: "index_device_chat_turns_on_child_chat_session_id_and_status"
    t.index ["child_chat_session_id", "turn_id"], name: "index_device_chat_turns_on_child_chat_session_id_and_turn_id", unique: true
    t.index ["child_chat_session_id"], name: "index_device_chat_turns_on_child_chat_session_id"
    t.index ["child_chat_session_id"], name: "index_device_chat_turns_on_one_processing_per_session", unique: true, where: "status = 'processing'"
    t.index ["user_message_id"], name: "index_device_chat_turns_on_user_message_id"
  end

  create_table "device_discoveries", force: :cascade do |t|
    t.string "device_id", null: false
    t.datetime "first_seen_at", null: false
    t.datetime "last_seen_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["device_id"], name: "index_device_discoveries_on_device_id", unique: true
  end

  create_table "disciplines", force: :cascade do |t|
    t.integer "student_id"
    t.string "title"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "date"
    t.index ["student_id"], name: "index_disciplines_on_student_id"
  end

  create_table "educational_videos", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.string "stage", null: false
    t.string "level", null: false
    t.string "subject", null: false
    t.integer "min_age", null: false
    t.integer "max_age", null: false
    t.string "status", default: "draft", null: false
    t.integer "admin_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_id"], name: "index_educational_videos_on_admin_id"
    t.index ["min_age", "max_age"], name: "index_educational_videos_on_min_age_and_max_age"
    t.index ["status"], name: "index_educational_videos_on_status"
    t.index ["subject"], name: "index_educational_videos_on_subject"
  end

  create_table "external_email_recipients", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_external_email_recipients_on_active"
    t.index ["email"], name: "index_external_email_recipients_on_email", unique: true
  end

  create_table "growth_records", force: :cascade do |t|
    t.integer "student_id", null: false
    t.date "recorded_on", null: false
    t.string "author_role", null: false
    t.integer "author_id", null: false
    t.text "note"
    t.text "analysis"
    t.string "positive_tags", default: "", null: false
    t.string "watch_tags", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["student_id", "recorded_on"], name: "index_growth_records_on_student_id_and_recorded_on"
    t.index ["student_id"], name: "index_growth_records_on_student_id"
  end

  create_table "parent_students", force: :cascade do |t|
    t.integer "parent_id"
    t.integer "student_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "pending", null: false
    t.index ["parent_id", "student_id"], name: "index_parent_students_on_parent_id_and_student_id", unique: true
    t.index ["student_id"], name: "index_parent_students_on_student_id"
  end

  create_table "parenting_advice_content_items", force: :cascade do |t|
    t.string "title", null: false
    t.string "source", null: false
    t.date "date", null: false
    t.string "url", null: false
    t.string "thumbnail"
    t.string "topic", null: false
    t.string "age_group", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source", "date"], name: "index_parenting_advice_content_items_on_source_and_date"
    t.index ["topic", "age_group"], name: "index_parenting_advice_content_items_on_topic_and_age_group"
    t.index ["url"], name: "index_parenting_advice_content_items_on_url", unique: true
  end

  create_table "parenting_advice_deliveries", force: :cascade do |t|
    t.integer "parenting_advice_schedule_id", null: false
    t.datetime "scheduled_run_at", null: false
    t.string "status", default: "running", null: false
    t.integer "sent_count", default: 0, null: false
    t.integer "failed_count", default: 0, null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email_subject"
    t.text "email_text_snapshot"
    t.text "email_html_snapshot"
    t.text "ai_analysis"
    t.text "ai_prompt_snapshot"
    t.index ["parenting_advice_schedule_id", "scheduled_run_at"], name: "index_pa_deliveries_on_schedule_and_run_at", unique: true
    t.index ["parenting_advice_schedule_id"], name: "index_pa_deliveries_on_schedule_id"
  end

  create_table "parenting_advice_delivery_content_items", force: :cascade do |t|
    t.integer "parenting_advice_delivery_id", null: false
    t.integer "parenting_advice_content_item_id", null: false
    t.integer "position", null: false
    t.string "title", null: false
    t.string "source", null: false
    t.date "date", null: false
    t.string "url", null: false
    t.string "thumbnail"
    t.string "topic", null: false
    t.string "age_group", null: false
    t.text "summary", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parenting_advice_content_item_id"], name: "index_pa_delivery_items_on_content_item_id"
    t.index ["parenting_advice_delivery_id", "position"], name: "index_pa_delivery_items_on_delivery_and_position", unique: true
    t.index ["parenting_advice_delivery_id", "url"], name: "index_pa_delivery_items_on_delivery_and_url", unique: true
    t.index ["parenting_advice_delivery_id"], name: "index_pa_delivery_items_on_delivery_id"
  end

  create_table "parenting_advice_delivery_recipients", force: :cascade do |t|
    t.integer "parenting_advice_delivery_id", null: false
    t.string "name"
    t.string "email", null: false
    t.string "status", null: false
    t.datetime "sent_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parenting_advice_delivery_id", "email"], name: "index_pa_delivery_recipients_on_delivery_and_email"
    t.index ["parenting_advice_delivery_id"], name: "index_pa_delivery_recipients_on_delivery_id"
  end

  create_table "parenting_advice_schedule_recipients", force: :cascade do |t|
    t.integer "parenting_advice_schedule_id", null: false
    t.string "recipient_type", null: false
    t.integer "recipient_id"
    t.string "name", null: false
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parenting_advice_schedule_id", "email"], name: "index_pa_schedule_recipients_on_schedule_and_email", unique: true
    t.index ["parenting_advice_schedule_id"], name: "index_pa_schedule_recipients_on_schedule_id"
  end

  create_table "parenting_advice_schedules", force: :cascade do |t|
    t.integer "admin_id"
    t.string "title", null: false
    t.text "body", null: false
    t.string "recurrence", null: false
    t.datetime "scheduled_at"
    t.string "send_time"
    t.integer "weekday"
    t.datetime "next_run_at"
    t.string "status", default: "active", null: false
    t.string "source_type", default: "custom", null: false
    t.text "source_config", default: "{}", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_id"], name: "index_parenting_advice_schedules_on_admin_id"
    t.index ["status", "next_run_at"], name: "index_pa_schedules_on_status_and_next_run_at"
  end

  create_table "parents", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "phone_number"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email"
    t.index ["email"], name: "index_parents_on_email"
    t.index ["phone_number"], name: "index_parents_on_phone_number", unique: true
  end

  create_table "students", force: :cascade do |t|
    t.string "first_name"
    t.string "second_name"
    t.string "surname"
    t.integer "age"
    t.string "description"
    t.integer "admission_number"
    t.integer "classroom_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "password_digest"
    t.index ["admission_number"], name: "index_students_on_admission_number", unique: true
    t.index ["classroom_id"], name: "index_students_on_classroom_id"
  end

  create_table "teachers", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "career_name"
    t.string "password_digest"
    t.string "phone_number"
    t.string "email"
    t.string "gender"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["career_name"], name: "index_teachers_on_career_name", unique: true
    t.index ["email"], name: "index_teachers_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "attendances", "classrooms"
  add_foreign_key "attendances", "students"
  add_foreign_key "child_chat_messages", "child_chat_sessions"
  add_foreign_key "child_chat_sessions", "child_devices"
  add_foreign_key "child_chat_sessions", "parents"
  add_foreign_key "child_chat_sessions", "students"
  add_foreign_key "child_devices", "students"
  add_foreign_key "child_tts_audios", "child_chat_messages"
  add_foreign_key "classrooms", "teachers", on_delete: :nullify
  add_foreign_key "device_chat_turns", "child_chat_messages", column: "assistant_message_id"
  add_foreign_key "device_chat_turns", "child_chat_messages", column: "user_message_id"
  add_foreign_key "device_chat_turns", "child_chat_sessions"
  add_foreign_key "disciplines", "students"
  add_foreign_key "educational_videos", "admins", on_delete: :nullify
  add_foreign_key "growth_records", "students"
  add_foreign_key "parent_students", "parents"
  add_foreign_key "parent_students", "students"
  add_foreign_key "parenting_advice_deliveries", "parenting_advice_schedules"
  add_foreign_key "parenting_advice_delivery_content_items", "parenting_advice_content_items"
  add_foreign_key "parenting_advice_delivery_content_items", "parenting_advice_deliveries"
  add_foreign_key "parenting_advice_delivery_recipients", "parenting_advice_deliveries"
  add_foreign_key "parenting_advice_schedule_recipients", "parenting_advice_schedules"
  add_foreign_key "parenting_advice_schedules", "admins", on_delete: :nullify
  add_foreign_key "students", "classrooms"
end
