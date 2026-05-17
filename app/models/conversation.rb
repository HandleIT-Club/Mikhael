# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
class Conversation < ApplicationRecord
  belongs_to :user
  has_many :messages,  dependent: :destroy
  has_many :memories,  dependent: :nullify

  # Delegamos al registry para evitar duplicar el mapping y para que la
  # memoización viva en un solo lugar.
  def self.all_models = Ai::ModelRegistry.all_models

  validates :model_id, presence: true, inclusion: { in: -> { Ai::ModelRegistry.all_models.keys } }
  validates :provider, presence: true

  before_validation :infer_provider
  before_validation :set_default_title

  scope :recent,  -> { order(updated_at: :desc) }
  scope :visible, -> { where(hidden: false) }

  def chat_messages
    messages.where.not(role: "system").order(:created_at)
  end

  # Mensajes que el AI debe recibir como contexto — excluye los anteriores al
  # context_cutoff_at (marcado cuando se genera una Memory de la conversación).
  def context_messages
    base = messages.where.not(role: "system").order(:created_at)
    context_cutoff_at ? base.where("created_at > ?", context_cutoff_at) : base
  end

  private

  # Siempre derivamos provider desde model_id para evitar estados inconsistentes
  # (ej: provider="ollama" con model_id de Groq pasa validación pero rompe en dispatch).
  def infer_provider
    self.provider = Ai::ModelRegistry.provider_for(model_id) if model_id
  end

  def set_default_title
    self.title ||= "Chat #{Time.current.strftime('%d/%m %H:%M')}"
  end
end
