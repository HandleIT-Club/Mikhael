# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
class Device < ApplicationRecord
  SECURITY_LEVELS = %w[normal high].freeze

  validates :device_id,      presence: true, uniqueness: true
  validates :name,           presence: true
  validates :system_prompt,  presence: true
  validates :security_level, inclusion: { in: SECURITY_LEVELS }
  validates :token,          presence: true, uniqueness: true

  before_validation :generate_token, on: :create

  def actions_list
    actions.to_s.split(",").map(&:strip).reject(&:empty?)
  end

  def high_security?
    security_level == "high"
  end

  def regenerate_token!
    update!(token: SecureRandom.hex(32))
  end

  private

  def generate_token
    self.token ||= SecureRandom.hex(32)
  end
end
