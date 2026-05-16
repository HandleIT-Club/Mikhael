class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string  :email,            null: false
      t.string  :password_digest,  null: false
      t.string  :telegram_chat_id              # nullable — el user lo linkea cuando quiere
      t.string  :api_token,        null: false # 256-bit; auto-generado en before_validation
      t.boolean :admin,            null: false, default: false

      t.timestamps
    end

    add_index :users, :email,            unique: true
    add_index :users, :telegram_chat_id, unique: true
    add_index :users, :api_token,        unique: true
  end
end
