# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Facade thin sobre los tres servicios de Ai/ que reemplazaron al monolito
# original:
#   - Ai::ModelRegistry  — qué modelos existen y a qué provider mapean
#   - Ai::Cooldown       — qué modelos están temporalmente rate-limited
#   - Ai::FallbackChain  — orden y next/first available
#
# Lo mantenemos por compatibilidad con callers existentes (operations,
# helpers de views, specs). Para código nuevo, usá las clases Ai/ directo.
class ModelSelector
  TIER_LABELS = {
    advanced:     "Avanzado",
    intermediate: "Intermedio",
    basic:        "Básico"
  }.freeze

  GROQ_TIERS      = Ai::ModelRegistry.tiers_of_provider("groq").freeze
  CEREBRAS_TIERS  = Ai::ModelRegistry.tiers_of_provider("cerebras").freeze
  SAMBANOVA_TIERS = Ai::ModelRegistry.tiers_of_provider("sambanova").freeze

  def self.mark_rate_limited(model_id) = Ai::Cooldown.mark(model_id)
  def self.rate_limited?(model_id)     = Ai::Cooldown.active?(model_id)
  def self.first_available             = Ai::FallbackChain.first_available
  def self.next_available(current)     = Ai::FallbackChain.next_available(current)
  def self.next_available_cloud(curr)  = Ai::FallbackChain.next_available_cloud(curr)

  def self.tier_of(model_id)    = Ai::ModelRegistry.tier_of(model_id)
  def self.tier_label(model_id) = TIER_LABELS[tier_of(model_id)]
end
