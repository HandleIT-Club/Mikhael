# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
module Api
  module V1
    class ModelsController < BaseController
      def index
        groups = [
          *tier_entries("groq", ModelSelector::GROQ_TIERS),
          *provider_entries("cerebras", ModelSelector::CEREBRAS_TIERS),
          *provider_entries("sambanova", ModelSelector::SAMBANOVA_TIERS),
          *ollama_entries
        ]
        render json: groups
      end

      private

      def tier_entries(provider, tiers)
        tiers.flat_map do |tier, models|
          models.map { |m| { model_id: m, provider: provider, tier: tier } }
        end
      end

      def provider_entries(provider, tiers)
        tiers.values.flatten.map { |m| { model_id: m, provider: provider, tier: nil } }
      end

      def ollama_entries
        OllamaModels.installed.map { |m| { model_id: m, provider: "ollama", tier: nil } }
      end
    end
  end
end
