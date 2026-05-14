class AddHiddenToConversations < ActiveRecord::Migration[8.1]
  def change
    add_column :conversations, :hidden, :boolean, default: false, null: false
    # Marcar conversaciones de Telegram preexistentes como ocultas.
    reversible do |dir|
      dir.up do
        execute "UPDATE conversations SET hidden = 1 WHERE title = 'Telegram'"
      end
    end
  end
end
