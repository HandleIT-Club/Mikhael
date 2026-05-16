class AddUserToScopedTables < ActiveRecord::Migration[8.1]
  def change
    # Per-user resources. Hacemos null: false porque la app va a wipe+restart
    # con el cambio a multi-user (decisión del owner). En producción real con
    # datos existentes esto sería un proceso de 2 pasos (nullable → backfill →
    # null: false), pero acá no aplica.
    add_reference :conversations, :user, null: false, foreign_key: true
    add_reference :reminders,     :user, null: false, foreign_key: true

    # Settings tiene dos personalidades:
    # - Per-user (timezone) → necesita user_id
    # - Global (telegram_poll_offset) → no
    # Resolvemos con user_id nullable + un índice compuesto en (user_id, key)
    # único para que cada user pueda tener su propio timezone, y el global
    # vive con user_id = NULL.
    add_reference :settings, :user, null: true, foreign_key: true
    remove_index  :settings, :key
    add_index     :settings, %i[user_id key], unique: true
  end
end
