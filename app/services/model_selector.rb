# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
class ModelSelector
  GROQ_TIERS = {
    advanced: %w[
      llama-3.3-70b-versatile
      meta-llama/llama-4-scout-17b-16e-instruct
      openai/gpt-oss-120b
    ],
    intermediate: %w[
      qwen/qwen3-32b
      openai/gpt-oss-20b
    ],
    basic: %w[
      llama-3.1-8b-instant
      allam-2-7b
    ]
  }.freeze

  CEREBRAS_TIERS = {
    advanced: %w[cerebras/llama-3.3-70b],
    basic:    %w[cerebras/llama3.1-8b]
  }.freeze

  SAMBANOVA_TIERS = {
    advanced: %w[sambanova/Meta-Llama-3.3-70B-Instruct sambanova/Meta-Llama-3.1-405B-Instruct],
    basic:    %w[sambanova/Meta-Llama-3.1-8B-Instruct]
  }.freeze

  ALL_GROQ      = GROQ_TIERS.values.flatten.freeze
  ALL_CEREBRAS  = CEREBRAS_TIERS.values.flatten.freeze
  ALL_SAMBANOVA = SAMBANOVA_TIERS.values.flatten.freeze
  ALL_CLOUD     = (ALL_GROQ + ALL_CEREBRAS + ALL_SAMBANOVA).freeze

  # Cadena groq → cerebras → sambanova → ollama. Es un método y no constante
  # porque los modelos Ollama instalados se descubren en runtime, y los providers
  # cloud sin API key configurada se filtran (no tiene sentido intentar y fallar).
  def self.fallback_chain
    chain = []
    chain.concat(ALL_GROQ)      if ENV["GROQ_API_KEY"].to_s.strip.present?
    chain.concat(ALL_CEREBRAS)  if ENV["CEREBRAS_API_KEY"].to_s.strip.present?
    chain.concat(ALL_SAMBANOVA) if ENV["SAMBANOVA_API_KEY"].to_s.strip.present?
    chain.concat(OllamaModels.installed)
    chain
  end

  TIER_LABELS = {
    advanced:     "Avanzado",
    intermediate: "Intermedio",
    basic:        "Básico"
  }.freeze

  COOLDOWN = 2.minutes

  def self.mark_rate_limited(model_id)
    Rails.cache.write(cache_key(model_id), true, expires_in: COOLDOWN)
  end

  def self.rate_limited?(model_id)
    Rails.cache.exist?(cache_key(model_id))
  end

  def self.first_available
    fallback_chain.find { |m| !rate_limited?(m) }
  end

  def self.next_available(current_model_id)
    chain = fallback_chain
    idx   = chain.index(current_model_id)
    return nil unless idx
    chain[(idx + 1)..].find { |m| !rate_limited?(m) }
  end

  # Variante de next_available que no cae a Ollama: la usa el fallback de
  # conversaciones, que prefiere fallar antes que cambiar al modelo local.
  def self.next_available_cloud(current_model_id)
    chain = fallback_chain
    idx   = chain.index(current_model_id)
    return nil unless idx
    chain[(idx + 1)..].find { |m| ALL_CLOUD.include?(m) && !rate_limited?(m) }
  end

  def self.tier_of(model_id)
    all = GROQ_TIERS.merge(CEREBRAS_TIERS).merge(SAMBANOVA_TIERS)
    all.find { |_, models| models.include?(model_id) }&.first
  end

  def self.tier_label(model_id)
    TIER_LABELS[tier_of(model_id)]
  end

  private_class_method def self.cache_key(model_id)
    "model_selector:rate_limited:#{model_id}"
  end
end
