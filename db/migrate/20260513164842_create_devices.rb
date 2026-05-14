class CreateDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :devices do |t|
      t.string :device_id,      null: false
      t.string :name,           null: false
      t.text   :system_prompt,  null: false, default: ""
      t.string :security_level, null: false, default: "normal"
      t.string :token,          null: false

      t.timestamps
    end
    add_index :devices, :device_id, unique: true
    add_index :devices, :token, unique: true
  end
end
