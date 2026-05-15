class CreateReminders < ActiveRecord::Migration[8.1]
  def change
    create_table :reminders do |t|
      t.datetime :scheduled_for, null: false
      t.text     :message,       null: false
      t.string   :kind,          null: false, default: "notify"
      t.integer  :device_id                   # nullable — solo para kind=query_device
      t.datetime :executed_at                 # nil = pendiente

      t.timestamps
    end

    add_index :reminders, :scheduled_for
    add_index :reminders, :executed_at
  end
end
