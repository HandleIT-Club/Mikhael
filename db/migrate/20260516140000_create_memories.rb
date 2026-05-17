class CreateMemories < ActiveRecord::Migration[8.1]
  def change
    create_table :memories do |t|
      t.integer :user_id,         null: false
      t.integer :conversation_id             # nullable: resúmenes manuales sin conversación específica
      t.text    :summary,         null: false
      t.string  :keywords,        null: false

      t.timestamps
    end

    add_index :memories, :user_id
    add_index :memories, :conversation_id
    add_foreign_key :memories, :users
    add_foreign_key :memories, :conversations

    add_column :conversations, :context_cutoff_at, :datetime
  end
end
