# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Fuente de verdad de qué modelos AI existen y a qué provider corresponden.
#
# Responsabilidad única: enumerar modelos. NO sabe nada de cooldown,
# fallback order, ni de la conversación. Eso vive en Ai::Cooldown y
# Ai::FallbackChain.
#
# Distinción importante:
#   - all_models      → catálogo COMPLETO. Lo usa Conversation.model_id para
#                       validar inclusion. Una conversación con un modelo
#                       Groq es VÁLIDA aunque hoy GROQ_API_KEY esté ausente
#                       (simplemente no la podés correr).
#   - cloud_model_ids → solo cloud habilitados por ENV. Lo usa
#                       Ai::FallbackChain para decidir qué corremos AHORA.
#
# Ollama: se descubre en runtime via /api/tags y se cachea 60s en
# OllamaModels. Si Ollama no responde, queda fuera del catálogo.
#
# Memoization: la lista combinada se cachea por proceso con TTL corto
# (REFRESH_TTL). Esto evita que cada Conversation.valid? haga round-trip al
# cache de Ollama. El TTL es chico para que un model nuevo en Ollama aparezca
# pronto sin reiniciar.
module Ai
  class ModelRegistry
    REFRESH_TTL = 30.seconds

    CLOUD_PROVIDERS = {
      "groq"      => {
        env: "GROQ_API_KEY",
        tiers: {
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
        }
      },
      "cerebras"  => {
        env: "CEREBRAS_API_KEY",
        tiers: {
          advanced: %w[cerebras/llama-3.3-70b],
          basic:    %w[cerebras/llama3.1-8b]
        }
      },
      "sambanova" => {
        env: "SAMBANOVA_API_KEY",
        tiers: {
          advanced: %w[
            sambanova/Meta-Llama-3.3-70B-Instruct
            sambanova/Meta-Llama-3.1-405B-Instruct
          ],
          basic:    %w[sambanova/Meta-Llama-3.1-8B-Instruct]
        }
      }
    }.freeze

    OLLAMA_PROVIDER = "ollama".freeze

    class << self
      # Hash { model_id => provider } incluyendo cloud habilitados + ollama
      # instalado. Memoizado por proceso con TTL para evitar round-trips
      # innecesarios desde la validation de Conversation.
      def all_models
        cached = @all_models_cache
        return cached[:value] if cached && cached[:at] > REFRESH_TTL.ago

        value = build_all_models
        @all_models_cache = { value: value.freeze, at: Time.current }
        value
      end

      # Lista plana de model_ids cloud habilitados (sin Ollama). Útil cuando
      # querés evitar caer al modelo local.
      def cloud_model_ids
        CLOUD_PROVIDERS.flat_map { |provider, cfg| enabled_provider?(provider) ? cfg[:tiers].values.flatten : [] }.freeze
      end

      # Devuelve el provider string ("groq", "cerebras", "ollama"...) para un
      # model_id, o nil si no existe.
      def provider_for(model_id)
        all_models[model_id]
      end

      # Tier (:advanced/:intermediate/:basic) del model_id si pertenece a un
      # provider con tiers (cloud), o nil si es Ollama o desconocido.
      def tier_of(model_id)
        CLOUD_PROVIDERS.each_value do |cfg|
          tier = cfg[:tiers].find { |_, models| models.include?(model_id) }&.first
          return tier if tier
        end
        nil
      end

      def tiers_of_provider(provider)
        CLOUD_PROVIDERS.dig(provider, :tiers) || {}
      end

      def enabled_provider?(provider)
        return false unless CLOUD_PROVIDERS.key?(provider)
        ENV[CLOUD_PROVIDERS[provider][:env]].to_s.strip.present?
      end

      # Para tests/dev: rompe el memo sin esperar al TTL.
      def reset!
        @all_models_cache = nil
      end

      private

      # Catálogo COMPLETO de cloud (sin filtrar por ENV) + Ollama instalado.
      # Para validación. La disponibilidad runtime la decide FallbackChain.
      def build_all_models
        result = {}
        CLOUD_PROVIDERS.each do |provider, cfg|
          cfg[:tiers].each_value { |models| models.each { |m| result[m] = provider } }
        end
        OllamaModels.installed.each { |m| result[m] = OLLAMA_PROVIDER }
        result
      end
    end
  end
end
