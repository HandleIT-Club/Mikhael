# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Usuario de Mikhael. Multi-user con signup CERRADO — solo el admin crea
# cuentas (vía `bin/mikhael:invite` o Rails console). No hay registro
# público porque Mikhael es un asistente personal/familiar, no SaaS.
#
# API token:
#   - El plain solo existe en memoria durante el request que lo genera.
#   - En DB guardamos api_token_digest = HMAC-SHA256(plain, secret_key_base).
#   - El lookup desde Authorization Bearer pasa por User.find_by_api_token,
#     que hashea el plain entrante y busca por digest. Determinístico, así
#     que el índice unique sigue funcionando.
#   - Si perdés el plain (no lo guardaste en .env del CLI), regenerás un
#     nuevo via bin/rails users:regenerate_token — el viejo deja de servir.
#
# Modelo de recursos:
#   - Per-user: Conversation, Reminder, Setting per-user (ej: timezone propia)
#   - Compartidos (hogar): Device, contexto del asistente. Configurables solo por admin.
class User < ApplicationRecord
  has_secure_password

  has_many :conversations, dependent: :destroy
  has_many :reminders,     dependent: :destroy
  has_many :settings,      dependent: :destroy
  has_many :memories,      dependent: :destroy

  validates :email,    presence: true, uniqueness: { case_sensitive: false },
                       format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 12 }, if: -> { password.present? }
  validates :telegram_chat_id, uniqueness: true, allow_blank: true
  validates :api_token_digest, presence: true, uniqueness: true

  normalizes :email, with: ->(e) { e.strip.downcase }

  before_validation :ensure_api_token_digest

  # Plain token disponible solo después de creación/regeneración. nil para
  # users cargados desde la DB.
  attr_reader :api_token

  # Vuelve a generar un token plain, persiste su HMAC, y deja el plain en
  # memoria para que el caller (bin/rails users:regenerate_token) lo muestre.
  def regenerate_api_token!
    plain = self.class.generate_api_token_plain
    update!(api_token_digest: self.class.hash_token(plain))
    @api_token = plain
  end

  def self.find_by_api_token(plain)
    return nil if plain.blank?
    find_by(api_token_digest: hash_token(plain))
  end

  def self.generate_api_token_plain
    SecureRandom.hex(32) # 256 bits
  end

  def self.hash_token(plain)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, plain)
  end

  # Para uso desde Rails console / rake: User.create_admin!(email:, password:)
  def self.create_admin!(email:, password:)
    create!(email: email, password: password, password_confirmation: password, admin: true)
  end

  private

  # En creación, si no hay digest, generamos un plain fresco y lo memoizamos.
  # El plain solo está disponible vía #api_token inmediatamente después.
  def ensure_api_token_digest
    return if api_token_digest.present?
    plain = self.class.generate_api_token_plain
    self.api_token_digest = self.class.hash_token(plain)
    @api_token = plain
  end
end
