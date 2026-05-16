# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Define la cadena de fallback entre modelos: groq → cerebras → sambanova → ollama.
# Salta los modelos que están en cooldown.
#
# La cadena se computa fresca cada vez (no se cachea) porque ModelRegistry
# ya memoiza la lista base y filtrar por cooldown debe ser instantáneo.
module Ai
  class FallbackChain
    ORDER = %w[groq cerebras sambanova ollama].freeze

    class << self
      def first_available
        chain.find { |m| !Cooldown.active?(m) }
      end

      def next_available(current_model_id)
        idx = chain.index(current_model_id)
        return nil unless idx
        chain[(idx + 1)..].find { |m| !Cooldown.active?(m) }
      end

      # Variante sin Ollama: la usa CreateMessage como fallback de
      # conversación, que prefiere fallar antes que cambiar al modelo local.
      def next_available_cloud(current_model_id)
        cloud = ModelRegistry.cloud_model_ids
        idx   = chain.index(current_model_id)
        return nil unless idx
        chain[(idx + 1)..].find { |m| cloud.include?(m) && !Cooldown.active?(m) }
      end

      private

      # Solo cloud habilitados por ENV (no todo el catálogo) + Ollama instalado.
      # Si GROQ_API_KEY no está seteada, Groq no entra en la chain — sin
      # sentido intentar y fallar.
      def chain
        cloud = ModelRegistry.cloud_model_ids                  # filtrado por ENV
        full  = ModelRegistry.all_models.select { |m, prov| prov == ModelRegistry::OLLAMA_PROVIDER || cloud.include?(m) }
        by_provider = full.group_by { |_, prov| prov }
        ORDER.flat_map { |prov| (by_provider[prov] || []).map(&:first) }
      end
    end
  end
end
