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

ActiveRecord::Schema.define(version: 20190103144540) do

  create_table "articles", force: :cascade do |t|
    t.text "message"
    t.string "article_type"
    t.integer "chat_id"
    t.integer "message_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "chats", force: :cascade do |t|
    t.integer "chat_id"
    t.string "chat_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "aasm_state"
  end

  create_table "contact_chats", force: :cascade do |t|
    t.string "state"
    t.integer "chat_id"
    t.string "chat_type"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "aasm_state"
    t.index ["user_id"], name: "index_contact_chats_on_user_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.string "sku"
    t.string "phone"
    t.string "email"
    t.string "name"
    t.string "city"
    t.string "region"
    t.text "own_comment"
    t.string "action"
    t.date "system_date"
    t.string "state"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "duties", force: :cascade do |t|
    t.integer "team"
    t.string "number"
    t.string "leader"
    t.date "day"
    t.integer "start_hour"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "duties_users", id: false, force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "duty_id", null: false
  end

  create_table "kv_chats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.boolean "authorized"
    t.string "username"
    t.string "city"
    t.string "cell"
    t.string "number"
    t.text "jobs"
    t.integer "team"
    t.integer "timezone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "widgets", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.integer "stock"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
