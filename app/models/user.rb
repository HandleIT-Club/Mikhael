# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Usuario de Mikhael. Multi-user con signup CERRADO — solo el admin crea
# cuentas (vía `bin/mikhael:invite` o Rails console). No hay registro
# público porque Mikhael es un asistente personal/familiar, no SaaS.
#
# Modelo de recursos:
#   - Per-user: Conversation, Reminder, UserSetting (ej: timezone propia)
#   - Compartidos (hogar): Device, ModelConfig
class User < ApplicationRecord
  has_secure_password

  has_many :conversations, dependent: :destroy
  has_many :reminders,     dependent: :destroy
  has_many :settings,      dependent: :destroy

  validates :email,    presence: true, uniqueness: { case_sensitive: false },
                       format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 12 }, if: -> { password.present? }
  validates :telegram_chat_id, uniqueness: true, allow_blank: true
  validates :api_token,        presence: true, uniqueness: true

  normalizes :email, with: ->(e) { e.strip.downcase }

  before_validation :ensure_api_token

  def regenerate_api_token!
    update!(api_token: self.class.generate_api_token)
  end

  def self.generate_api_token
    SecureRandom.hex(32) # 256 bits
  end

  # Para uso desde Rails console / rake: User.create_admin!(email:, password:)
  def self.create_admin!(email:, password:)
    create!(email: email, password: password, password_confirmation: password, admin: true)
  end

  private

  def ensure_api_token
    self.api_token ||= self.class.generate_api_token
  end
end
