class Conversation < ApplicationRecord
  has_many :messages, dependent: :destroy

  MODELS = {
    "llama3.2:3b"      => "ollama",
    "qwen2.5-coder:3b" => "ollama",
    "llama-3.3-70b-versatile"                    => "groq",
    "meta-llama/llama-4-scout-17b-16e-instruct"  => "groq"
  }.freeze

  validates :provider, presence: true, inclusion: { in: %w[ollama groq] }
  validates :model_id, presence: true, inclusion: { in: MODELS.keys }

  before_validation :infer_provider
  before_validation :set_default_title

  scope :recent, -> { order(updated_at: :desc) }

  def chat_messages
    messages.where.not(role: "system").order(:created_at)
  end

  private

  def infer_provider
    self.provider ||= MODELS[model_id] if model_id
  end

  def set_default_title
    self.title ||= "Chat #{Time.current.strftime('%d/%m %H:%M')}"
  end
end
