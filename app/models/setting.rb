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

  def self.set_for(user, key, value)
    record       = where(user_id: user.id).find_or_initialize_by(key: key)
    record.value = value.to_s
    record.save!
    value
  end
end
