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

ActiveRecord::Schema[8.1].define(version: 2026_05_16_130000) do
  create_table "conversations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "hidden", default: false, null: false
    t.string "model_id"
    t.string "provider"
    t.string "system_prompt_fingerprint"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index [ "user_id" ], name: "index_conversations_on_user_id"
  end

  create_table "devices", force: :cascade do |t|
    t.text "actions"
    t.datetime "created_at", null: false
    t.string "device_id", null: false
    t.datetime "last_seen_at"
    t.string "name", null: false
    t.string "security_level", default: "normal", null: false
    t.text "system_prompt", default: "", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index [ "device_id" ], name: "index_devices_on_device_id", unique: true
    t.index [ "token" ], name: "index_devices_on_token", unique: true
  end

  create_table "messages", force: :cascade do |t|
    t.text "content"
    t.integer "conversation_id", null: false
    t.datetime "created_at", null: false
    t.string "model_id"
    t.string "provider"
    t.string "role"
    t.datetime "updated_at", null: false
    t.index [ "conversation_id", "created_at" ], name: "index_messages_on_conversation_id_and_created_at"
    t.index [ "conversation_id" ], name: "index_messages_on_conversation_id"
  end

  create_table "reminders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "device_id"
    t.datetime "executed_at"
    t.string "kind", default: "notify", null: false
    t.text "message", null: false
    t.datetime "scheduled_for", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index [ "device_id" ], name: "index_reminders_on_device_id"
    t.index [ "executed_at" ], name: "index_reminders_on_executed_at"
    t.index [ "scheduled_for" ], name: "index_reminders_on_scheduled_for"
    t.index [ "user_id" ], name: "index_reminders_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.text "value"
    t.index [ "user_id", "key" ], name: "index_settings_on_user_id_and_key", unique: true
    t.index [ "user_id" ], name: "index_settings_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.string "api_token_digest", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "telegram_chat_id"
    t.datetime "updated_at", null: false
    t.index [ "api_token_digest" ], name: "index_users_on_api_token_digest", unique: true
    t.index [ "email" ], name: "index_users_on_email", unique: true
    t.index [ "telegram_chat_id" ], name: "index_users_on_telegram_chat_id", unique: true
  end

  add_foreign_key "conversations", "users"
  add_foreign_key "messages", "conversations"
  add_foreign_key "reminders", "devices", on_delete: :nullify
  add_foreign_key "reminders", "users"
  add_foreign_key "settings", "users"
end
