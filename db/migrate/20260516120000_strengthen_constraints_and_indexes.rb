class StrengthenConstraintsAndIndexes < ActiveRecord::Migration[8.1]
  def change
    # Reminder.device_id: FK con on_delete: nullify para que al borrar un
    # device los reminders queden con device_id=NULL en vez de FK colgada.
    # Además, el index nos da lookups baratos cuando borrás un device y
    # cuando ExecuteReminderJob busca por device.
    add_index :reminders, :device_id
    add_foreign_key :reminders, :devices, on_delete: :nullify

    # Messages: ordenamos por created_at dentro de una conversation en cada
    # render del chat. El index compuesto sirve la query directo (sin filesort)
    # cuando la conversación crece.
    add_index :messages, %i[conversation_id created_at]
  end
end
