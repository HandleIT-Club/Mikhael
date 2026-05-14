# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
class Conversation < ApplicationRecord
  has_many :messages, dependent: :destroy

  CLOUD_MODELS = {
    "llama-3.3-70b-versatile"                    => "groq",
    "meta-llama/llama-4-scout-17b-16e-instruct"  => "groq",
    "openai/gpt-oss-120b"                        => "groq",
    "qwen/qwen3-32b"                             => "groq",
    "openai/gpt-oss-20b"                         => "groq",
    "llama-3.1-8b-instant"                       => "groq",
    "allam-2-7b"                                 => "groq",
    "cerebras/llama-3.3-70b"                     => "cerebras",
    "cerebras/llama3.1-8b"                       => "cerebras",
    "sambanova/Meta-Llama-3.3-70B-Instruct"      => "sambanova",
    "sambanova/Meta-Llama-3.1-405B-Instruct"     => "sambanova",
    "sambanova/Meta-Llama-3.1-8B-Instruct"       => "sambanova"
  }.freeze

  def self.all_models
    ollama = OllamaModels.installed.index_with("ollama")
    CLOUD_MODELS.merge(ollama)
  end

  validates :model_id, presence: true, inclusion: { in: -> { Conversation.all_models.keys } }
  validates :provider, presence: true

  before_validation :infer_provider
  before_validation :set_default_title

  scope :recent,  -> { order(updated_at: :desc) }
  scope :visible, -> { where(hidden: false) }

  def chat_messages
    messages.where.not(role: "system").order(:created_at)
  end

  private

  # Siempre derivamos provider desde model_id para evitar estados inconsistentes
  # (ej: provider="ollama" con model_id de Groq pasa validación pero rompe en dispatch).
  def infer_provider
    self.provider = self.class.all_models[model_id] if model_id
  end

  def set_default_title
    self.title ||= "Chat #{Time.current.strftime('%d/%m %H:%M')}"
  end
end
