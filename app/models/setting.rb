# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Key-value store persistente respaldado por la DB principal.
# Pensado para configuración runtime que tiene que sobrevivir reinicios y que
# no encaja en otros modelos (ej: offset del polling de Telegram). NO usar
# para datos de usuario o contenido — esto es plumbing.
class Setting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  def self.get(key, default = nil)
    find_by(key: key)&.value || default
  end

  def self.set(key, value)
    record       = find_or_initialize_by(key: key)
    record.value = value.to_s
    record.save!
    value
  end
end
