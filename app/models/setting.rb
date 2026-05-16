# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Key-value store persistente respaldado por la DB principal.
#
# Tiene dos modos:
#   - Global (user_id NULL): config de la app que NO es per-user.
#     Ej: "telegram_poll_offset" (un solo bot, un solo offset).
#   - Per-user (user_id presente): config personal de cada user.
#     Ej: "user_timezone" — cada user su zona.
#
# La unicidad es (user_id, key), no solo key — así dos users pueden tener
# distintos timezones.
class Setting < ApplicationRecord
  belongs_to :user, optional: true

  validates :key, presence: true, uniqueness: { scope: :user_id }

  # ─── API global ───────────────────────────────────────────────────────────
  def self.get(key, default = nil)
    where(user_id: nil).find_by(key: key)&.value || default
  end

  # No usamos upsert porque SQLite trata NULL como ≠ NULL en UNIQUE — dos
  # filas globales con la misma key pasarían el índice. El único uso real es
  # `telegram_poll_offset`, escrito por un solo job a la vez (advisory lock).
  def self.set(key, value)
    record       = where(user_id: nil).find_or_initialize_by(key: key)
    record.value = value.to_s
    record.save!
    value
  end

  # ─── API per-user ─────────────────────────────────────────────────────────
  def self.get_for(user, key, default = nil)
    return default if user.nil?
    where(user_id: user.id).find_by(key: key)&.value || default
  end

  # Upsert atómico (sin race condition entre dos requests/jobs concurrentes
  # del mismo user). El índice único (user_id, key) es efectivo cuando
  # user_id NO es NULL.
  def self.set_for(user, key, value)
    return value if user.nil?
    upsert({ user_id: user.id, key: key.to_s, value: value.to_s }, unique_by: %i[user_id key])
    value
  end
end
