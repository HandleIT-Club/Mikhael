# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
class Device < ApplicationRecord
  SECURITY_LEVELS = %w[normal high].freeze
  ONLINE_THRESHOLD = 2.minutes

  # Actions persistidas como JSON array (antes era CSV — frágil para nombres
  # con comas y serialización inconsistente). Default a [] para que sea
  # siempre un Array y nunca nil.
  serialize :actions, coder: JSON, type: Array

  validates :device_id,      presence: true, uniqueness: true
  validates :name,           presence: true
  validates :system_prompt,  presence: true
  validates :security_level, inclusion: { in: SECURITY_LEVELS }
  validates :token,          presence: true, uniqueness: true

  before_validation :generate_token, on: :create
  before_validation :normalize_actions

  # Compat: el caller (forms, AssistantContext, etc.) sigue llamando
  # actions_list y esperando un Array. Ahora actions ya ES un Array, así que
  # solo limpiamos defensivamente.
  def actions_list
    Array(actions).map(&:to_s).map(&:strip).reject(&:empty?)
  end

  def high_security?
    security_level == "high"
  end

  def online?
    last_seen_at.present? && last_seen_at >= ONLINE_THRESHOLD.ago
  end

  def touch_last_seen!
    update_column(:last_seen_at, Time.current)
  end

  def regenerate_token!
    update!(token: SecureRandom.hex(32))
  end

  private

  def generate_token
    self.token ||= SecureRandom.hex(32)
  end

  # Acepta tanto un Array como un string CSV (cuando viene del form HTML que
  # no sabe mandar arrays sin parámetros especiales). Esto centraliza el cast
  # y evita que el form layer se preocupe del formato persistido.
  def normalize_actions
    return if actions.is_a?(Array)
    self.actions = actions.to_s.split(",").map(&:strip).reject(&:empty?)
  end
end
